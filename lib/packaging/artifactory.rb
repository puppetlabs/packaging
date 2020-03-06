require 'artifactory'
require 'uri'
require 'open-uri'
require 'digest'

#
# [eric.griswold] This is unfortunate. The 'pattern_search' class method really does belong in
# the Artifactory gem. However, because of some of Chef's social policies,
# I am unwilling to contribute this code there. If that changes, I'll submit a PR. Until
# then, it'll live here.
#
module Artifactory
  class Resource::Artifact
    #
    # Search for an artifact in a repo using an Ant-like pattern.
    # Unlike many Artifactory searches, this one is restricted to a single
    # repository.
    #
    # @example Search in a repository named 'foo_local' for an artifact in a directory containing
    #   the word "recent", named "artifact[0-9].txt"
    #   Artifact.pattern_search(pattern: '*recent*/artifact[0-9].txt',
    #                           repo: 'foo_local')
    #
    # @param [Hash] options
    #   A hash of options, as follows:
    #
    # @option options [Artifactory::Client] :client
    #   the client object to make the request with
    # @option options [String] :pattern
    #   the Ant-like pattern to use for finding artifacts within the repos. Note that the
    #   Ant pattern '**' is barred in this case by JFrog.
    # @option options [String] :repo
    #   the repo to search
    #
    # @return [Array<Resource::Artifact>]
    #   a list of artifacts that match the query
    #
    def self.pattern_search(options = {})
      client = extract_client!(options)
      params = Util.slice(options, :pattern, :repo)
      pattern_search_parameter = { :pattern => "#{params[:repo]}:#{params[:pattern]}" }
      response = client.get('/api/search/pattern', pattern_search_parameter)
      return [] if response['files'].nil? || response['files'].empty?

      # A typical response:
      # {
      #  "repoUri"=>"https:<artifactory endpoint>/<repo>",
      #  "sourcePattern"=>"<repo>:<provided search pattern>",
      #  "files"=>[<filename that matched pattern>, ...]
      # }
      #
      # Inserting '/api/storage' before the repo makes the 'from_url' call work correctly.
      #
      repo_uri = response['repoUri']
      unless repo_uri.include?('/api/storage/')
        # rubocop:disable Style/PercentLiteralDelimiters
        repo_uri.sub!(%r(/#{params[:repo]}$), "/api/storage/#{params[:repo]}")
      end
      response['files'].map do |file_path|
        from_url("#{repo_uri}/#{file_path}", client: client)
      end
    end
  end
end


module Pkg

  # The Artifactory class
  # This class provides automation to access the artifactory repos maintained
  # by the Release Engineering team at Puppet. It has the ability to both push
  # artifacts to the repos, and to retrieve them back from the repos.
  class ManageArtifactory

    # The Artifactory property that the artifactCleanup user plugin
    # {https://github.com/jfrog/artifactory-user-plugins/tree/master/cleanup/artifactCleanup}
    # uses to tell it to not clean a particular artifact
    ARTIFACTORY_CLEANUP_SKIP_PROPERTY = 'cleanup.skip'

    DEFAULT_REPO_TYPE = 'generic'
    DEFAULT_REPO_BASE = 'development'

    # @param project [String] The name of the project this package is for
    # @param project_version [String] The version of the project we want the
    #   package for. This can be one of three things:
    #     1) the final tag of the project the packages  were built from
    #     2) the long git sha the project the packages were built from
    #     3) the EZBake generated development sha where the packages live
    # @option :artifactory_uri [String] the uri for the artifactory server.
    #   This currently defaults to 'https://artifactory.delivery.puppetlabs.net/artifactory'
    # @option :repo_base [String] The base of all repos, set for consistency.
    #   This currently defaults to 'development'
    def initialize(project, project_version, opts = {})
      @artifactory_uri = opts[:artifactory_uri] || 'https://artifactory.delivery.puppetlabs.net/artifactory'
      @repo_base = opts[:repo_base] || DEFAULT_REPO_BASE

      @project = project
      @project_version = project_version

      Artifactory.endpoint = @artifactory_uri
    end

    # @param platform_tag [String] The platform tag string for the repo we need
    #   information on. If generic information is needed, pass in `generic`
    # @return [Array] An array containing three items, first being the main repo
    #   name for the platform_tag, the second being the subdirectories of the
    #   repo leading to the artifact we want to install, and the third being the
    #   alternate subdirectories for a given repo. This last option is only
    #   currently used for debian platforms, where the path to the repo
    #   specified in the list file is different than the full path to the repo.
    def location_for(platform_tag)
      toplevel_repo = DEFAULT_REPO_TYPE
      repo_subdirectories = File.join(@repo_base, @project, @project_version)
      alternate_subdirectories = repo_subdirectories

      unless platform_tag == DEFAULT_REPO_TYPE
        format = Pkg::Platforms.package_format_for_tag(platform_tag)
        platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
      end

      case format
      when 'rpm'
        toplevel_repo = 'rpm'
        repo_subdirectories = File.join(repo_subdirectories, "#{platform}-#{version}-#{architecture}")
        alternate_subdirectories = repo_subdirectories
      when 'deb'
        toplevel_repo = 'debian__local'
        repo_subdirectories = File.join(repo_subdirectories, "#{platform}-#{version}")
        alternate_subdirectories = File.join('pool', repo_subdirectories)
      when 'swix', 'dmg', 'svr4', 'ips'
        repo_subdirectories = File.join(repo_subdirectories, "#{platform}-#{version}-#{architecture}")
        alternate_subdirectories = repo_subdirectories
      when 'msi'
        repo_subdirectories = File.join(repo_subdirectories, "#{platform}-#{architecture}")
        alternate_subdirectories = repo_subdirectories
      end

      [toplevel_repo, repo_subdirectories, alternate_subdirectories]
    end

    # @param platform_tag [String] The platform tag specific to the information
    #   we need. If only the generic information is needed, pass in `generic`
    # @return [Hash] Returns a hash of data specific to this platform tag
    def platform_specific_data(platform_tag)
      unless platform_tag == DEFAULT_REPO_TYPE
        platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
        package_format = Pkg::Platforms.package_format_for_tag(platform_tag)
        if package_format == 'deb'
          codename = Pkg::Platforms.codename_for_platform_version(platform, version)
        end
      end

      repo_name, repo_subdirectories, alternate_subdirectories = location_for(platform_tag)
      full_artifactory_path = File.join(repo_name, alternate_subdirectories)

      {
        platform: platform,
        platform_version: version,
        architecture: architecture,
        codename: codename,
        package_format: package_format,
        repo_name: repo_name,
        repo_subdirectories: repo_subdirectories,
        alternate_subdirectories: alternate_subdirectories,
        full_artifactory_path: full_artifactory_path
      }
    end

    # @param platform_tag [String] The platform to generate the list contents
    #   for
    # @return [String] The contents of the debian list file to enable the
    #   debian artifactory repos for the specified project and version
    def deb_list_contents(platform_tag)
      data = platform_specific_data(platform_tag)
      if data[:package_format] == 'deb'
        return "deb #{@artifactory_uri}/#{data[:repo_name]} #{data[:codename]} #{data[:repo_subdirectories]}"
      end
      raise "The platform '#{platform_tag}' is not an apt-based system."
    end

    # @param platform_tag [String] The platform to generate the repo file
    #   contents for
    # @return [String] The contents of the rpm repo file to enable the rpm
    #   artifactory repo for the specified project and version
    def rpm_repo_contents(platform_tag)
      data = platform_specific_data(platform_tag)
      if data[:package_format] == 'rpm'
        return <<-DOC
  [Artifactory #{@project} #{@project_version} for #{platform_tag}]
  name=Artifactory Repository for #{@project} #{@project_version} for #{platform_tag}
  baseurl=#{@artifactory_uri}/#{data[:repo_name]}/#{data[:repo_subdirectories]}
  enabled=1
  gpgcheck=0
  #Optional - if you have GPG signing keys installed, use the below flags to verify the repository metadata signature:
  #gpgkey=#{@artifactory_uri}/#{data[:repo_name]}/#{data[:repo_subdirectories]}/repomd.xml.key
  #repo_gpgcheck=1
        DOC
      end
      raise "The platform '#{platform_tag}' is not a yum-based system"
    end

    # Verify the correct environment variables are set in order to process
    # authorization to access the artifactory repos
    def check_authorization
      unless (ENV['ARTIFACTORY_USERNAME'] && ENV['ARTIFACTORY_PASSWORD']) || ENV['ARTIFACTORY_API_KEY']
        raise <<-DOC
  Unable to determine credentials for Artifactory. Please set one of the
  following environment variables:

  For basic authentication, please set:
  ARTIFACTORY_USERNAME
  ARTIFACTORY_PASSWORD

  If you would like to use the API key, ensure ARTIFACTORY_USERNAME and
  ARTIFACTORY_PASSWORD are not set, as these take precedence. Instead, please
  set:
  ARTIFACTORY_API_KEY

  You can also set the path to a pem file with your custom certificates with:
  ARTIFACTORY_SSL_PEM_FILE
        DOC
      end
    end

    # @param platform_tag [String] The platform tag to generate deploy
    #   properties for
    # @return [String] Any required extra bits that we need for the curl
    #   command used to deploy packages to artifactory
    #
    #   These are a few examples from chef/artifactory-client. These could
    #   potentially be very powerful, but we should decide how to use them.
    #     status: 'DEV',
    #     rating: 5,
    #     branch: 'master'
    #
    #   Currently we are including everything that would be included in the yaml
    #   file that is generated at package build time.
    def deploy_properties(platform_tag)
      data = platform_specific_data(platform_tag)

      # TODO This method should be returning the entire contents of the yaml
      # file in hash form to include as metadata for these artifacts. In this
      # current iteration, the hash isn't formatted properly and the attempt to
      # deploy to Artifactory bails out. I'm leaving this in so that we at least
      # have multiple places to remind us that it needs to happen.
      #properties_hash = Pkg::Config.config_to_hash
      properties_hash = {}
      if data[:package_format] == 'deb'
        properties_hash.merge!({
          'deb.distribution' => data[:codename],
          'deb.component' => data[:repo_subdirectories],
          'deb.architecture' => data[:architecture],
        })
      end
      properties_hash
    end

    # Basic method to check if a package exists on artifactory
    # @param package [String] The full relative path to the package to be
    #   checked, relative from the current working directory
    # Return true if package already exists on artifactory
    def package_exists_on_artifactory?(package)
      check_authorization
      artifact = Artifactory::Resource::Artifact.search(name: File.basename(package), :artifactory_uri => @artifactory_uri)
      if artifact.empty?
        return false
      else
        return true
      end
    end

    # @param package [String] The full relative path to the package to be
    #   shipped, relative from the current working directory
    def deploy_package(package)
      platform_tag = Pkg::Paths.tag_from_artifact_path(package) || DEFAULT_REPO_TYPE
      data = platform_specific_data(platform_tag)

      check_authorization
      artifact = Artifactory::Resource::Artifact.new(local_path: package)
      artifact_md5 = Digest::MD5.file(package).hexdigest
      headers = { "X-Checksum-Md5" => artifact_md5 }
      artifact.upload(
        data[:repo_name],
        File.join(data[:alternate_subdirectories], File.basename(package)),
        deploy_properties(platform_tag),
        headers
      )
    rescue
      raise "Attempt to upload '#{package}' to #{File.join(@artifactory_uri, data[:full_artifactory_path])} failed"
    end

    # @param pkg [String] The package to download YAML for
    #   i.e. 'puppet-agent' or 'puppetdb'
    # @param ref [String] The git ref (sha or tag) we want the YAML for
    #
    # @return [String] The contents of the YAML file
    def retrieve_yaml_data(pkg, ref)
      yaml_url = "#{@artifactory_uri}/#{DEFAULT_REPO_TYPE}/#{DEFAULT_REPO_BASE}/#{pkg}/#{ref}/#{ref}.yaml"
      open(yaml_url) { |f| f.read }
    rescue
      raise "Failed to load YAML data for #{pkg} at #{ref} from #{yaml_url}!"
    end

    # @param platform_data [Hash] The hash of the platform data that needs to be
    #   parsed
    # @param platform_tag [String] The tag that the data we want belongs to
    # @return [String] The name of the package for the given project,
    #   project_version, and platform_tag
    def package_name(platform_data, platform_tag)
      return File.basename(platform_data[platform_tag][:artifact])
    rescue
      fail_message = <<-DOC
  Package name could not be found from loaded yaml data. Either this package
  does not exist, or '#{platform_tag}' is not present in this dataset.

  The following are available platform tags for '#{@project}' '#{@project_version}':
    #{platform_data.keys.sort}
      DOC
      raise fail_message
    end

    # @param platform_data [Hash] The hash of the platform data that needs to be
    #   parsed
    # @param platform_tag [String] The tag that the data we want belongs to
    # @return [Array] An array containing all packages for the given project,
    #   project_version, and platform_tag
    def all_package_names(platform_data, platform_tag)
      packages = [platform_data[platform_tag][:artifact]]
      packages << platform_data[platform_tag][:additional_artifacts]
      packages.flatten!
      packages.reject! { |package| package.nil? || package.empty? }
      packages.map { |package| File.basename(package) }
    rescue
      fail_message = <<-DOC
  Package name could not be found from loaded yaml data. Either this package
  does not exist, or '#{platform_tag}' is not present in this dataset.

  The following are available platform tags for '#{@project}' '#{@project_version}':
    #{platform_data.keys.sort}
      DOC
      raise fail_message
    end

    # Promotes a build based on build SHA or tag (or SNAPSHOT version, for ezbake)
    # Depending on if it's an RPM or Deb package promote accordingly
    # 'promote' by copying the package(s) to the enterprise directory on artifactory
    #
    # @param pkg [String] the package name ex. puppet-agent
    # @param ref [String] tag or SHA of package(s) to be promoted
    # @param platform_tag [String] the platform tag of the artifact
    #   ex. el-7-x86_64, ubuntu-18.04-amd64
    # @param repository [String] the repository to promote
    #   the artifact to. Will prepend 'rpm_' or 'debian_' to the repositories
    #   depending on package type
    # @param debian_component [String] the debian component to promote packages
    #   into. Optional.
    def promote_package(pkg, ref, platform_tag, repository, debian_component = nil)
      # load package metadata
      yaml_content = retrieve_yaml_data(pkg, ref)
      yaml_data = YAML::load(yaml_content)

      # get the artifact name
      artifact_names = all_package_names(yaml_data[:platform_data], platform_tag)
      artifact_names.each do |artifact_name|
        artifact_search_results = Artifactory::Resource::Artifact.search(
          name: artifact_name, :artifactory_uri => @artifactory_uri)

        if artifact_search_results.empty?
          raise "Error: could not find PKG=#{pkg} at REF=#{ref} for #{platform_tag}"
        end
        artifact_to_promote = artifact_search_results[0]

        # This makes an assumption that we're using some consistent repo names
        # but need to either prepend 'rpm_' or 'debian_' based on package type
        case File.extname(artifact_name)
        when '.rpm'
          promotion_path = "rpm_#{repository}/#{platform_tag}/#{artifact_name}"
        when '.deb'
          promotion_path = "debian_#{repository}/#{platform_tag}/#{artifact_name}"
          properties = { 'deb.component' => debian_component } unless debian_component.nil?
        else
          raise "Error: Unknown promotion repository for #{artifact_name}! Only .rpm and .deb files are supported!"
        end

        begin
          source_path = artifact_to_promote.download_uri.sub(@artifactory_uri, '')
          puts "promoting #{artifact_name} from #{source_path} to #{promotion_path}"
          artifact_to_promote.copy(promotion_path)
          unless properties.nil?
            artifacts = Artifactory::Resource::Artifact.search(name: artifact_name, :artifactory_uri => @artifactory_uri)
            promoted_artifact = artifacts.select { |artifact| artifact.download_uri =~ %r{#{promotion_path}} }.first
            promoted_artifact.properties(properties)
          end
        rescue Artifactory::Error::HTTPError => e
          if e.message =~ /(destination and source are the same|user doesn't have permissions to override)/i
            puts "Skipping promotion of #{artifact_name}; it has already been promoted"
          else
            puts "#{e.message}"
            raise e
          end
        rescue => e
          puts "Something went wrong promoting #{artifact_name}!"
          raise e
        end
      end
    end

    # Using the manifest provided by enterprise-dist, grab the appropropriate packages from artifactory based on md5sum
    # @param staging_directory [String] location to download packages to
    # @param manifest [File] JSON file containing information about what packages to download and the corresponding md5sums
    # @param remote_path [String] Optional partial path on the remote host containing packages
    #        Used to specify which subdirectories packages will be downloaded from.
    def download_packages(staging_directory, manifest, remote_path = '')
      check_authorization
      manifest.each do |dist, packages|
        puts "Grabbing the #{dist} packages from artifactory"
        packages.each do |name, info|
          artifacts = Artifactory::Resource::Artifact.checksum_search(md5: "#{info["md5"]}", repos: ["rpm_enterprise__local", "debian_enterprise__local"])
          artifact_to_download = artifacts.select { |artifact| artifact.download_uri.include? remote_path }.first
          if artifact_to_download.nil?
            filename = info["filename"] || name
            message = "Error: what the hell, could not find package #{filename} with md5sum #{info["md5"]}"
            unless path.empty?
              message += " in #{path}"
            end
            raise message
          else
            full_staging_path = "#{staging_directory}/#{dist}"
            filename = info['filename'] || File.basename(artifact_to_download.download_uri)
            puts "downloading #{artifact_to_download.download_uri} to #{File.join(full_staging_path, filename)}"
            artifact_to_download.download(full_staging_path, filename: filename)
          end
        end
      end
    end

    # Ship PE tarballs to specified artifactory repo and paths
    # @param local_tarball_directory [String] the local directory containing the tarballs
    # @param target_repo [String] the artifactory repo to ship the tarballs to
    # @param ship_paths [Array] the artifactory path(s) to ship the tarballs to within
    #   the target_repo
    def ship_pe_tarballs(local_tarball_directory, target_repo, ship_paths)
      check_authorization
      ship_paths.each do |path|
        Dir.foreach(local_tarball_directory) do |pe_tarball|
          next if pe_tarball == '.' || pe_tarball == ".."
          begin
            puts "Uploading #{pe_tarball} to #{target_repo}/#{path}#{pe_tarball}"
            artifact = Artifactory::Resource::Artifact.new(
              local_path: "#{local_tarball_directory}/#{pe_tarball}")
            artifact.upload(target_repo, "#{path}#{pe_tarball}")
          rescue Errno::EPIPE
            STDERR.puts "Warning: Could not upload #{pe_tarball} to #{target_repo}/#{path}. Skipping."
            next
          end
        end
      end
    end

    # Upload file to Artifactory
    # @param local_path [String] local path to file to upload
    # @param target_repo [String] repo on artifactory to upload to
    # @param target_path [String] path within target_repo to upload to
    def upload_file(local_path, target_repo, target_path)
      fail "Error: Couldn't find file at #{local_path}." unless File.exist? local_path
      check_authorization
      artifact = Artifactory::Resource::Artifact.new(local_path: local_path)
      full_upload_path = File.join(target_path, File.basename(local_path))
      begin
        puts "Uploading #{local_path} to #{target_repo}/#{full_upload_path} . . ."
        artifact.upload(target_repo, full_upload_path)
      rescue Artifactory::Error::HTTPError => e
        fail "Error: Upload failed. Ensure path #{target_path} exists in the #{target_repo} repository."
      end
    end

    # Start by clearing the ARTIFACTORY_CLEANUP_SKIP_PROPERTY on all artifacts in a
    # single repo/directory location. This allows all artifacts in the directory to be cleaned.
    # Once cleared, set ARTIFACTORY_CLEANUP_SKIP_PROPERTY on those matching pe_build_version,
    # presumably the latest. This prevents those artifacts from being deleted.
    #
    # @param repo [String] Artifactory repository that contains the specified directory
    # @param directory [String] Artifactory directory in repo containing the artifacts from which to
    #   set the 'cleanup.skip' property setting to false
    # @param pe_build_version [String] Set 'cleanup.skip' property on artifacts that
    #   contain this string in their file inside the directory.
    def prevent_artifact_cleanup(repo, directory, pe_build_version)
      # Clean up any trailing slashes on directory, just in case
      directory.sub!(/(\/)+$/, '')

      all_artifacts_pattern = "#{directory}/*"
      latest_artifacts_pattern = "#{directory}/*#{pe_build_version}*"

      all_artifacts = Artifactory::Resource::Artifact.pattern_search(
        repo: repo,
        pattern: all_artifacts_pattern
      )
      latest_artifacts = Artifactory::Resource::Artifact.pattern_search(
        repo: repo,
        pattern: latest_artifacts_pattern
      )

      # Clear cleanup.skip on all artifacts in directory
      puts "Clearing #{ARTIFACTORY_CLEANUP_SKIP_PROPERTY} in #{repo}/#{all_artifacts_pattern}"
      all_artifacts.each do |artifact|
        artifact.properties(ARTIFACTORY_CLEANUP_SKIP_PROPERTY => false)
      end

      # Set cleanup.skip on all artifacts in directory matching *pe_build_version*
      puts "Setting #{ARTIFACTORY_CLEANUP_SKIP_PROPERTY} in #{repo}/#{latest_artifacts_pattern}"
      latest_artifacts.each do |artifact|
        artifact.properties(ARTIFACTORY_CLEANUP_SKIP_PROPERTY => true)
      end
    end

    # Search for artifacts matching `artifact_name` in `repo` with path matching
    # `path`
    # @param artifact_name [String] name of artifact to download
    # @param repo [String] repo the artifact lives
    # @param path [String] path to artifact in the repo
    #
    # @return [Array<Artifactory::Resource::Artifact>] A list of artifacts that
    #         match the query
    def search_with_path(artifact_id, repo, path)
      check_authorization
      artifacts = Artifactory::Resource::Artifact.search(name: artifact_id, repos: repo)
      artifacts.select { |artifact| artifact.download_uri.include? path }
    end

    # Download an artifact based on name, repo, and path to artifact
    # @param artifact_name [String] name of artifact to download
    # @param repo [String] repo the artifact lives
    # @param path [String] path to artifact in the repo
    # @param target [String] directory to download artifact to. Defaults to '.'
    # @param filename [String] Filename to save artifact as. Defaults to artifact_name
    def download_artifact(artifact_name, repo, path, target: '.', filename: nil)
      filename ||= artifact_name
      artifacts = search_with_path(artifact_name, repo, path)
      return nil if artifacts.empty?
      # Only download the first of the artifacts since we're saving them to
      # the same location anyways
      artifacts.first.download(target, filename: filename)
    end

    # Download final pe tarballs to local path based on name, repo, and path on artifactory
    # @param pe_version [String] pe final tag
    # @param repo [String] repo the tarballs live
    # @param remote_path [String] path to tarballs in the repo
    # @param local_path [String] local path to download tarballs to
    def download_final_pe_tarballs(pe_version, repo, remote_path, local_path)
      check_authorization
      artifacts = Artifactory::Resource::Artifact.search(name: pe_version, repos: repo)
      artifacts.each do |artifact|
        next unless artifact.download_uri.include? remote_path
        next if artifact.download_uri.include? "-rc"
        artifact.download(local_path)
      end
    end

    # Download beta pe tarballs to local path based on tag, repo, and path on artifactory
    # @param beta_tag [String] rc tag of beta release ex. 2019.2.0-rc10
    # @param repo [String] repo the tarballs live
    # @param remote_path [String] path to tarballs in the repo
    # @param local_path [String] local path to download tarballs to
    def download_beta_pe_tarballs(beta_tag, repo, remote_path, local_path)
      check_authorization
      pattern = "#{remote_path}/*-#{beta_tag}-*"
      artifacts = Artifactory::Resource::Artifact.pattern_search(repo: repo, pattern: pattern)
      artifacts.each do |artifact|
        artifact.download(local_path)
      end
    end

    # When we ship a new PE release we copy final tarballs to archives/releases
    # @param pe_version [String] pe final tag
    # @param repo [String] repo the tarballs live
    # @param remote_path [String] path to tarballs in the repo
    # @param target_path [String] path copy tarballs to, assumes same repo
    def copy_final_pe_tarballs(pe_version, repo, remote_path, target_path)
      check_authorization
      final_tarballs = Artifactory::Resource::Artifact.search(name: pe_version, repos: repo)
      final_tarballs.each do |artifact|
        next unless artifact.download_uri.include? remote_path
        next if artifact.download_uri.include? "-rc"
        filename = File.basename(artifact.download_uri)
        # Artifactory does NOT like when you use `File.join`, so let's concatenate!
        full_target_path = "#{repo}/#{target_path}/#{filename}"
        puts "INFO: Copying #{filename} to #{full_target_path} . . ."
        artifact.copy(full_target_path)
      end
    end

    # When we cut a new PE branch, we need to copy the pe components into <pe_version>/{repos,feature,release}/<platform>
    # @param manifest [File] JSON file containing information about what packages to download and the corresponding md5sums
    # @param target_path [String] path on artifactory to copy components to, e.g. <pe_version>/release
    def populate_pe_repos(manifest, target_path)
      check_authorization
      manifest.each do |dist, packages|
        puts "Copying #{dist} packages..."
        packages.each do |name, info|
          artifact = Artifactory::Resource::Artifact.checksum_search(md5: "#{info["md5"]}", repos: ["rpm_enterprise__local", "debian_enterprise__local"]).first
          if artifact.nil?
            filename = info["filename"] || info["name"]
            raise "Error: what the hell, could not find package #{filename} with md5sum #{info["md5"]}"
          end
          begin
            filename = info["filename"] || File.basename(artifact.download_uri)
            artifact_target_path = "#{artifact.repo}/#{target_path}/#{dist}/#{filename}"
            puts "Copying #{artifact.download_uri} to #{artifact_target_path}"
            artifact.copy(artifact_target_path)
          rescue Artifactory::Error::HTTPError
            STDERR.puts "Could not copy #{artifact_target_path}. Source and destination are the same. Skipping..."
          end
          if File.extname(filename) == '.deb'
            copied_artifact_search = Artifactory::Resource::Artifact.pattern_search(repo: 'debian_enterprise__local', pattern: "#{target_path}/*/#{filename}")
            fail "Error: what the hell, could not find just-copied package #{filename} under debian_enterprise__local/#{target_path}" if copied_artifact_search.nil?
            copied_artifact = copied_artifact_search.first
            properties = { 'deb.component' => Pkg::Paths.debian_component_from_path(target_path) }
            copied_artifact.properties(properties)
          end
        end
      end
    end

    # Remove all artifacts in repo based on pattern, used when we purge all artifacts in release/ after PE release
    # @param repos [Array] repos that we want to search for artifacts in
    # @param pattern [String] pattern for artifacts that should be deleted ex. `2019.1/release/*/*`
    def teardown_repo(repos, pattern)
      check_authorization
      repos.each do |repo|
        artifacts = Artifactory::Resource::Artifact.pattern_search(repo: repo, pattern: pattern)
        artifacts.each do |artifact|
          puts "Deleting #{artifact.download_uri}"
          artifact.delete
        end
      end
    end

    # Remove promoted artifacts if promotion is reverted, use information provided in manifest
    # @param manifest [File] JSON file containing information about what packages to download and the corresponding md5sums
    # @param remote_path [String] path on artifactory to promoted packages ex. 2019.1/repos/
    # @param package [String] package name ex. puppet-agent
    # @param repos [Array] the repos the promoted artifacts live
    def remove_promoted_packages(manifest, remote_path, package, repos)
      check_authorization
      manifest.each do |dist, packages|
        packages.each do |package_name, info|
          next unless package_name == package
          artifacts = Artifactory::Resource::Artifact.checksum_search(md5: "#{info["md5"]}", repos: repos)
          artifacts.each do |artifact|
            next unless artifact.download_uri.include? remote_path
            puts "Removing reverted package #{artifact.download_uri}"
            artifact.delete
          end
        end
      end
    end

    # Remove shipped PE tarballs from artifactory
    # Used when compose fails, we only want the tarball shipped to artifactory if all platforms succeed
    # Identify which packages were created and shipped based on md5sum and remove them
    # @param tarball_path [String] the local path to the tarballs that were shipped
    # @param pe_repo [String] the artifactory repo the tarballs were shipped to
    def purge_copied_pe_tarballs(tarball_path, pe_repo)
      check_authorization
      Dir.foreach("#{tarball_path}/") do |pe_tarball|
        next if pe_tarball == '.' || pe_tarball == ".."
        md5 = Digest::MD5.file("#{tarball_path}/#{pe_tarball}").hexdigest
        artifacts_to_delete = Artifactory::Resource::Artifact.checksum_search(md5: md5, repos: pe_repo)
        next if artifacts_to_delete.nil?
        begin
          artifacts_to_delete.each do |artifact|
            puts "Removing #{pe_tarball} from #{pe_repo}... "
            artifact.delete
          end
        rescue Artifactory::Error::HTTPError
          STDERR.puts "Error: cannot remove #{pe_tarball}, do you have the right permissions?"
        end
      end
    end

    private :check_authorization
  end
end
