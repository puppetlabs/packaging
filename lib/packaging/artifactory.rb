require 'uri'
require 'open-uri'

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

    # @param directory [String] optional, The directory where the yaml file will
    #   be downloaded
    # @return [String] The path to the downloaded file
    def retrieve_yaml_data_file(directory = nil)
      directory ||= Dir.mktmpdir
      retrieve_package(DEFAULT_REPO_TYPE, "#{@project_version}.yaml", directory)
      File.join(directory, "#{@project_version}.yaml")
    end

    # @param platform_data [Hash] The has of the platform data that needs to be
    #   parsed
    # @param platform_tag [String] The tag that the data we want belongs to
    # @return [String] The name of the package for the given project,
    #   project_version, and platform_tag
    def package_name(platform_data, platform_tag)
      return File.basename(platform_data[platform_tag][:artifact])
    rescue
      fail_message = <<-DOC
  Package name could not be found from loaded yaml data. Either this package
  does not exist, or '#{@platform_tag}' is not present in this dataset.

  The following are available platform tags for '#{@project}' '#{@project_version}':
    #{platform_data.keys.sort}
      DOC
      raise fail_message
    end

    # Promotes a build based on build SHA or tag
    # Depending on if it's an RPM or Deb package promote accordingly
    # 'promote' by copying the package(s) to the enterprise directory on artifactory
    #
    # @param pkg [String] the package name ex. puppet-agent
    # @param ref [String] tag or SHA of package(s) to be promoted
    # @param pe_version [String] enterprise version promoting to (XX.YY)
    # @param platform_tag [String] the platform tag of the artifact
    #   ex. el-7-x86_64, ubuntu-18.04-amd64
    def promote_package(pkg, ref, pe_version, platform_tag)
      yaml_url = @artifactory_uri + "/generic__local/development/#{pkg}/#{ref}/#{ref}.yaml"
      # grab the associated yaml file
      yaml_content = open(yaml_url){|f| f.read}
      yaml_data = YAML::load(yaml_content)
      # get the artifact name
      artifact_name = File.basename(yaml_data[:platform_data]["#{platform_tag}"][:artifact])
      artifact_to_promote = Artifactory::Resource::Artifact.search(name: artifact_name, :artifactory_uri => @artifactory_uri)
      if artifact_to_promote.empty?
        puts "Error: could not find PKG=#{pkg} at REF=#{git_ref} for #{platform_tag}"
      end
      # set the promotion path based on whether rpm or deb
      if File.extname(artifact_name) == '.rpm'
          promotion_path = "rpm_enterprise__local/#{pe_version}/repos/#{platform_tag}"
      else # 'deb'
          promotion_path = "debian_enterprise__local/#{pe_version}/repos/#{platform_tag}"
      end
      puts "promoting #{artifact_name} to #{promotion_path}"
      artifact_to_promote[0].copy(promotion_path)
      rescue
        raise "PROMOTION FAILED: #{artifact_name} has already been promoted"
    end

    # @param platform_tags [Array[String], String] optional, either a string, or
    #   an array of strings. These are the platform or platforms that we will
    #   download packages for.
    # @param package [String] optional, the name of the package to be
    #   retrieved. If the user does not know this information, we can derive it
    #   from the yaml data. This ignores everything but the package name. Any
    #   customization for where the user wants to fetch the package is via the
    #   download_path parameter.
    # @param download_path [String] Optional, an optional path set to where
    #   the user wants the retrieved package to end up. If no path is specified
    #   this defaults to the pkg directory.
    def retrieve_package(platform_tags = nil, package = nil, download_path = nil)

      if platform_tags.nil? && !package.nil?
        platform_tags = Pkg::Paths.tag_from_artifact_path(package) || DEFAULT_REPO_TYPE
      elsif platform_tags.nil? && package.nil?
        yaml_file = retrieve_yaml_data_file(download_path)
        yaml_data = Pkg::Config.config_from_yaml(yaml_file)
        platform_data = yaml_data[:platform_data]
        platform_tags = platform_data.keys
      end

      Array(platform_tags).each do |platform_tag|
        puts "fetching package for #{platform_tag}"
        data = platform_specific_data(platform_tag)
        if package.nil?
          package_for_tag = package_name(platform_data, platform_tag)
          puts "package name is #{package_for_tag}"
        else
          package_for_tag = package
        end
        download_path_for_tag = download_path || data[:repo_subdirectories].sub(@repo_base, 'pkg')

        check_authorization
        artifact = Artifactory::Resource::Artifact.new(
          download_uri: File.join(@artifactory_uri, data[:full_artifactory_path], File.basename(package_for_tag))
        )
        artifact.download(download_path_for_tag)
      end
    rescue
      raise "Attempt to download '#{File.basename(package)}' from #{File.join(@artifactory_uri, data[:full_artifactory_path])} failed."
    end

    private :check_authorization
  end
end
