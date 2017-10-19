module Pkg

  # The Artifactory class
  # This class provides automation to access the artifactory repos maintained
  # by the Release Engineering team at Puppet. It has the ability to both push
  # artifacts to the repos, and to retrieve them back from the repos.
  class ManageArtifactory
    require 'artifactory'

    # @param project [String] The name of the project this package is for
    # @param project_version [String] The version of the project we want the
    #   package for. This can be one of three things:
    #     1) the final tag of the project the packages  were built from
    #     2) the long git sha the project the packages were built from
    #     3) the EZBake generated development sha where the packages live
    # @param platform_tag [String] Either the platform tag for the
    #   platform we want deal with packages for (i.e., el-7-x86_64 or
    #   ubuntu-16.04-amd64), or 'generic' for those packages or archives
    #   that are platform independent (i.e., tar, gem, etc)
    # @option :artifactory_url [String] the uri for the artifactory server.
    #   This currently defaults to 'https://artifactory.delivery.puppetlabs.net/artifactory'
    # @option :repo_base [String] The base of all repos, set for consistency.
    #   This currently defaults to 'development'
    #
    # rubocop:disable Metrics/AbcSize
    def initialize(project, project_version, platform_tag = 'generic', opts = {})
      @artifactory_url = opts[:artifactory_url] || 'https://artifactory.delivery.puppetlabs.net/artifactory'
      @repo_base = opts[:repo_base] || 'development'

      @project = project
      @project_version = project_version
      @platform_tag = platform_tag

      unless platform_tag == 'generic'
        @platform, @platform_version, @architecture = Pkg::Platforms.parse_platform_tag(@platform_tag)
        @package_format = Pkg::Platforms.package_format_for_tag(@platform_tag)
        if @package_format == 'deb'
          @codename = Pkg::Platforms.codename_for_platform_version(@platform, @platform_version)
        end
      end

      @repo_name, @repo_subdirectories = location_for

      Artifactory.endpoint = @artifactory_url
      check_authorization
    end

    # @return [Array] An array containing two items, first being the main repo
    #   name for the platform_tag, the second being the subdirectories of the
    #   repo leading to the artifact we want to install
    def location_for(format = @package_format)
      toplevel_repo = 'generic'
      repo_subdirectories = File.join(@repo_base, @project, @project_version)

      case format
      when 'rpm'
        toplevel_repo = 'rpm'
        repo_subdirectories = File.join(repo_subdirectories, "#{@platform}-#{@platform_version}-#{@architecture}")
      when 'deb'
        toplevel_repo = 'debian__local'
      when 'swix', 'dmg', 'svr4', 'ips'
        repo_subdirectories = File.join(repo_subdirectories, "#{@platform}-#{@platform_version}-#{@architecture}")
      when 'msi'
        repo_subdirectories = File.join(repo_subdirectories, "#{@platform}-#{@architecture}")
      end

      [toplevel_repo, repo_subdirectories]
    end

    def alternate_subdirectory_path
      subdirectories = @repo_subdirectories
      if @package_format == 'deb'
        subdirectories = File.join('pool', @repo_subdirectories)
      end

      subdirectories
    end

    def retrieve_yaml_data_file(tmpdir)
      toplevel_repo, repo_subdirectories = location_for('yaml')
      artifactory_repo_path = "#{@artifactory_url}/#{toplevel_repo}/#{repo_subdirectories}"
      retrieve_package("#{@project_version}.yaml", tmpdir, artifactory_repo_path)
    end

    # @return [Hash] The data loaded from the retrieved yaml file for the
    #   given project and version
    def yaml_platform_data
      tmpdir = Dir.mktmpdir
      retrieve_yaml_data_file(tmpdir)
      yaml_hash = YAML.load_file(File.join(tmpdir, "#{@project_version}.yaml"))
      yaml_hash[:platform_data]
    end

    # @return [String] The name of the package for the given project,
    #   project_version, and platform_tag
    def package_name
      File.basename(yaml_platform_data[@platform_tag][:artifact])
    end

    # @return [String] The contents of the debian list file to enable the
    #   debian artifactory repos for the specified project and version
    def deb_list_contents
      if @package_format == 'deb'
        "deb #{@artifactory_url}/#{@repo_name} #{@codename} #{@repo_subdirectories}"
      else
        ''
      end
    end

    # @return [String] The contents of the rpm repo file to enable the rpm
    #   artifactory repo for the specified project and version
    def rpm_repo_contents
      if @package_format == 'rpm'
        <<-DOC
  [Artifactory #{@project} #{@project_version} for #{@platform_tag}]
  name=Artifactory Repository for #{@project} #{@project_version} for #{@platform_tag}
  baseurl=#{@artifactory_url}/#{@repo_name}/#{@repo_subdirectories}
  enabled=1
  gpgcheck=0
  #Optional - if you have GPG signing keys installed, use the below flags to verify the repository metadata signature:
  #gpgkey=#{@artifactory_url}/#{@repo_name}/#{@repo_subdirectories}/repomd.xml.key
  #repo_gpgcheck=1
        DOC
      else
        ''
      end
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

    # @return [String] Any required extra bits that we need for the curl
    #   command used to deploy packages to artifactory
    #
    #   These are a few examples from chef/artifactory-client. These could
    #   potentially be very powerful, but we should decide how to use them.
    #     status: 'DEV',
    #     rating: 5,
    #     branch: 'master'
    def deploy_properties
      if @package_format == 'deb'
        return {
          'deb.distribution' => @codename,
          'deb.component' => @repo_subdirectories,
          'deb.architecture' => @architecture,
        }
      end
      {}
    end

    # @param package [String] The full relative path to the package to be
    #   shipped, relative from the current working directory
    def deploy_package(package)
      artifact = Artifactory::Resource::Artifact.new(local_path: package)
      artifact.upload(@repo_name, File.join(alternate_subdirectory_path, File.basename(package)), deploy_properties)
    rescue
      raise "Attempt to upload #{package} to #{@artifactory_url} in the #{@repo_name} repo failed"
    end

    # @param package [String] optional, the name of the package to be
    #   retrieved. If the user does not know this information, we can derive it
    #   from the yaml data. This ignores everything but the package name. Any
    #   customization for where the user wants to fetch the package is via the
    #   download_path parameter.
    # @param download_path [String] Optional, an optional path set to where
    #   the user wants the retrieved package to end up. If no path is specified
    #   this defaults to the pkg directory.
    def retrieve_package(package = nil, download_path = nil, artifactory_repo_path = nil)
      package ||= package_name
      download_path ||= @repo_subdirectories.sub(@repo_base, 'pkg')
      artifactory_repo_path ||= "#{@artifactory_url}/#{@repo_name}/#{alternate_subdirectory_path}"

      artifact = Artifactory::Resource::Artifact.new(download_uri: File.join(artifactory_repo_path, File.basename(package)))
      artifact.download(download_path)
    rescue
      raise "Attempt to download package '#{package}' from #{@artifactory_url}/#{@repo_name}/#{alternate_subdirectory_path} failed."
    end

    private :location_for, :deploy_properties, :retrieve_yaml_data_file,
      :yaml_platform_data, :check_authorization, :alternate_subdirectory_path
  end
end
