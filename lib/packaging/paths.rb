# Utilities surrounding the appropriate paths associated with a platform
# This includes both reporting the correct path and divining the platform
# tag associated with a variety of paths
#
# rubocop:disable Metrics/ModuleLength
module Pkg::Paths
  include Pkg::Platforms

  module_function

  # Given a path to an artifact, divine the appropriate platform tag associated
  # with the artifact and path
  #
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  def tag_from_artifact_path(path)
    Pkg::Platforms.supported_platforms.each do |platform|
      next unless path.include?(platform)
      if platform == 'windows'
        # Windows is special, we don't care about the version, so we put in
        # 2012 here mainly as a place holder
        Pkg::Platforms.arches_for_platform_version(platform, '2012').each do |architecture|
          return "#{platform}-2012-#{architecture}" if path.include?(architecture)
        end
        # Default to 64bit if we can't find an architecture
        return "#{platform}-2012-x64"
      end
      Pkg::Platforms.versions_for_platform(platform).each do |version|
        next unless path =~ /#{platform}(\/|-)?#{version}/
        # Default to 64bit for no reason in particular
        return "#{platform}-#{version}-x86_64" if path.include?('noarch')
        Pkg::Platforms.arches_for_platform_version(platform, version).each do |architecture|
          return "#{platform}-#{version}-#{architecture}" if path.include?(architecture)
        end
      end
    end

    # If we haven't been able to match against a platform name, we're likely
    # dealing with a codename
    Pkg::Platforms.codenames('deb').each do |codename|
      next unless path.include?(codename)
      # Default to 64bit for no reason in particular
      return "#{Pkg::Platforms.codename_to_platform_version(codename).join('-')}-amd64" if path.include?('all')
      Pkg::Platforms.arches_for_codename(codename).each do |arch|
        return "#{Pkg::Platforms.codename_to_platform_version(codename).join('-')}-#{arch}" if path.include?(arch)
      end
    end
    raise "I couldn't figure out which platform tag corresponds to #{path}. Teach me?"
  end

  def artifacts_path(platform_tag, package_url = nil, path_prefix = 'artifacts')
    platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm'
      File.join(path_prefix, Pkg::Config.repo_name, platform, version, architecture)
    when 'swix'
      File.join(path_prefix, platform, Pkg::Config.repo_name, version, architecture)
    when 'deb'
      File.join(path_prefix, 'deb', Pkg::Platforms.get_attribute(platform_tag, :codename), Pkg::Config.repo_name)
    when 'svr4', 'ips'
      File.join(path_prefix, 'solaris', Pkg::Config.repo_name, version)
    when 'dmg'
      File.join(path_prefix, 'mac', Pkg::Config.repo_name, version, architecture)
    when 'msi'
      File.join(path_prefix, 'windows', Pkg::Config.repo_name)
    else
      raise "Not sure where to find packages with a package format of '#{package_format}'"
    end
  end

  def repo_path(platform_tag)
    platform, version, arch = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm', 'swix'
      File.join('repos', Pkg::Config.repo_name, platform, version, arch)
    when 'deb'
      File.join('repos', 'apt', Pkg::Platforms.get_attribute(platform_tag, :codename), 'pool', Pkg::Config.repo_name)
    when 'svr4', 'ips'
      File.join('repos', 'solaris', Pkg::Config.repo_name, version)
    when 'dmg'
      File.join('repos', 'mac', Pkg::Config.repo_name, version, arch)
    when 'msi'
      File.join('repos', 'windows', Pkg::Config.repo_name)
    else
      raise "Not sure what to do with a package format of '#{package_format}'"
    end
  end

  def repo_config_path(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm'
      # rpm/pl-puppet-agent-1.2.5-el-5-i386.repo for example
      File.join('repo_configs', 'rpm', "*#{platform_tag}*.repo")
    when 'deb'
      # deb/pl-puppet-agent-1.2.5-jessie.list
      File.join('repo_configs', 'deb', "*#{Pkg::Platforms.get_attribute(platform_tag, :codename)}*.list")
    when 'msi', 'swix', 'dmg', 'svr4', 'ips'
      nil
    else
      raise "Not sure what to do with a package format of '#{package_format}'"
    end
  end
end
