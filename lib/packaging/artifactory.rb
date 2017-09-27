module Pkg::Platforms
  module_function

  ARTIFACTORY_URL = 'http://artifactory.delivery.puppetlabs.net/artifactory'
  CURL = 'curl'

  default_repo = 'development'

  def artifactory_authorization
    #"--user #{user_name}:#{api_token}"
    ''
  end

  def debian_extras(platform_tag)
    platform, version, arch = Pkg::Util::Platform.parse_platform_tag(platform_tag)
    codename = Pkg::Platforms::PLATFORM_INFO[platform][version][:codename]
    fail "Codename not found for #{platform_tag}; cannot push to correct Artifactory repo." unless codename
    ";deb.distribution=#{codename};deb.component=#{default_repo};deb.architecture=#{architecture}"
  end

  # package: full path to the package relative to the current working directory
  def artifactory_curl_command(package, platform_tag)
    curl_extras = ''
    case package
    when /\.debian\.tar\.gz$/, /\.dsc$/, /\.deb$/, /\.orig\.tar\.gz$/, /\.changes$/
      toplevel_repo = 'deb__local/pool'
      repo_subdirectories = ''
      curl_extras = debian_extras(platform_tag)
    when /\.rpm$/
      toplevel_repo = 'rpm'
      repo_subdirectories = ''

      platform, version, arch = Pkg::Util::Platform.parse_platform_tag(platform_tag)

      # Repo subdirectory options for rpm packages:
      #
      # 'el-7-x86_64/', 'fedora-25-i386/'
      # 'el/7/x86_64/', 'fedora/25/i386/'
      # 'el-7/', 'fedora-25/'
      # 'el/7/', 'fedora/25/'
    when /\.swix(.asc)?$/, /\.tar\.gz(.asc)?$/, /\.msi$/, /\.dmg$/
      toplevel_repo = 'generic'

      case package
      when /\.swix(.asc)?$/
        # Repo subdirectory option for swix packages:
        #
        # ''
        # 'eos/'
        # 'eos/4/'
        # 'eos-4/'
        # 'eos/4/i386/'
        # 'eos-4-i386/'
      when /\.tar\.gz(.asc)?$/
        # Repo subdirectory option for tar archives:
        #
        # ''
        # '$project'
      when /\.msi$/
        # Repo subdirectory option for msi packages:
        #
        # ''
        # 'windows'
        # 'windows/x86'
        # 'windows-x86'
      when /\.dmg$/
        # Repo subdirectory option for dmg packages:
        #
        # ''
        # 'mac/'
        # 'mac/10.12/'
        # 'mac-10.12/'
        # 'mac/10.12/x86_64/'
        # 'mac-10.12-x86_64/'
      end
    when /\.gem$/
      toplevel_repo = 'rubygems/gems'
    else
      fail "unable to determine which repo type #{package} belongs to"
    end
    "#{CURL} #{artifactory_authorization} '#{ARTIFACTORY_URL}/#{toplevel_repo}/#{repo_subdirectories}#{File.basename(package)}#{curl_extras}' --upload-file #{package}"
  end

  # TODO: open questions
  # - How do we want to structure these repos
  #   * flat layout versus a tree
  #   * Isolated in their own directory?
  #   * tree layout, what format do we want to follow
  # - where do the metadata files end up?
  #   * ezbake manifests
  #   * sha.yaml
  #   * build_metadata.json
  #   * signing bundle
  #   * etc
  # - Are we going to isolate the different builds like we have been on
  #   builds.delivery.puppetlabs.net, or are all development builds going to be
  #   shipped to the same repo?
  # - Are we going to ship development builds to their targeted repo?
  #   * i.e., PC1 vs. puppet5 vs pupppet8 vs etc
  #   * This may result in duplicate builds if we ever need to ship one thing
  #     to multiple repos, which is a thing we have done before
  # - If all development builds share a repo rather than having an individual
  #   repo per project, per build, do we have limits on how long metadata
  #   generation and regeneration can take?
end
