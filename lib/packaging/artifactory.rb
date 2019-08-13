require 'uri'
require 'open-uri'
require 'digest'

module Pkg

  # The Artifactory class
  # This class provides automation to access the artifactory repos maintained
  # by the Release Engineering team at Puppet. It has the ability to both push
  # artifacts to the repos, and to retrieve them back from the repos.
  class ManageArtifactory

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
      require 'artifactory'

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

    # @param package [String] The full relative path to the package to be
    #   shipped, relative from the current working directory
    def deploy_package(package)
      platform_tag = Pkg::Paths.tag_from_artifact_path(package) || DEFAULT_REPO_TYPE
      data = platform_specific_data(platform_tag)

      check_authorization
      artifact = Artifactory::Resource::Artifact.new(local_path: package)
      artifact.upload(
        data[:repo_name],
        File.join(data[:alternate_subdirectories], File.basename(package)),
        deploy_properties(platform_tag)
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
        artifact_to_promote = Artifactory::Resource::Artifact.search(name: artifact_name, :artifactory_uri => @artifactory_uri)

        if artifact_to_promote.empty?
          raise "Error: could not find PKG=#{pkg} at REF=#{git_ref} for #{platform_tag}"
        end

        # This makes an assumption that we're using some consistent repo names
        # but need to either prepend 'rpm_' or 'debian_' based on package type
        if File.extname(artifact_name) == '.rpm'
          promotion_path = "rpm_#{repository}/#{platform_tag}/#{artifact_name}"
        elsif File.extname(artifact_name) == '.deb'
          promotion_path = "debian_#{repository}/#{platform_tag}/#{artifact_name}"
          properties = { 'deb.component' => debian_component } unless debian_component.nil?
        else
          raise "Error: Unknown promotion repository for #{artifact_name}! Only .rpm and .deb files are supported!"
        end

        begin
          puts "promoting #{artifact_name} to #{promotion_path}"
          artifact_to_promote[0].copy(promotion_path)
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
    def download_packages(staging_directory, manifest)
      check_authorization
      manifest.each do |dist, packages|
        puts "Grabbing the #{dist} packages from artifactory"
        packages.each do |name, info|
          artifact_to_download = Artifactory::Resource::Artifact.checksum_search(md5: "#{info["md5"]}", repos: ["rpm_enterprise__local", "debian_enterprise__local"]).first
          if artifact_to_download.nil?
            raise "Error: what the hell, could not find package #{info["filename"]} with md5sum #{info["md5"]}"
          else
            puts "downloading #{artifact_to_download.download_uri}"
            artifact_to_download.download("#{staging_directory}/#{dist}", filename: "#{info["filename"]}")
          end
        end
      end
    end

    # Ship PE tarballs to specified artifactory repo and paths
    # @param tarball_path [String] the path of the tarballs to ship
    # @param target_repo [String] the artifactory repo to ship the tarballs to
    # @param ship_paths [Array] the artifactory path(s) to ship the tarballs to within the target_repo
    def ship_pe_tarballs(tarball_path, target_repo, ship_paths)
      check_authorization
      Dir.foreach("#{tarball_path}/") do |pe_tarball|
        unless pe_tarball == '.' || pe_tarball == ".."
          ship_paths.each do |path|
            begin
              puts "Uploading #{pe_tarball} to #{target_repo}/#{path}... "
              artifact = Artifactory::Resource::Artifact.new(local_path: "#{tarball_path}/#{pe_tarball}")
              artifact.upload(target_repo, "/#{path}/#{pe_tarball}")
            rescue Errno::EPIPE
              STDERR.puts "Error: Could not upload #{pe_tarball} to #{path}"
            end
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
