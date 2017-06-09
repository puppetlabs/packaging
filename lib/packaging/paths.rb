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
  def tag_from_artifact_path(path)
    platform = Pkg::Platforms.supported_platforms.find { |p| path.include?(p) }
    if platform == 'windows'
      version = '2012'
      arch = Pkg::Platforms::arches_for_platform_version(platform, version).find { |a| path.include?(a) }
      if arch.nil?
        arch = 'x64'
      end
    elsif !platform.nil?
      version = Pkg::Platforms.versions_for_platform(platform).find { |v|  path =~ /#{platform}(\/|-)?#{v}/ }
      unless version.nil?
        arch = Pkg::Platforms::arches_for_platform_version(platform, version).find { |a| path.include?(a) }
        if arch.nil? && path.include?('ppc')
          arch = 'power'
        elsif arch.nil?
          arch = 'x86_64'
        end
      end
    end
    # if we didn't find a platform or a version, probably a codename
    if platform.nil? || version.nil?
      codename = Pkg::Platforms.codenames('deb').find { |c| path.include?(c) }
      fail "I can't find a codename or platform in #{path}, teach me?" if codename.nil?
      platform, version = Pkg::Platforms.codename_to_platform_version(codename)
      fail "I can't find a platform and version from #{codename}, teach me?" if platform.nil? || version.nil?
      arch = Pkg::Platforms.arches_for_platform_version(platform, version).find { |a| path.include?(a) }
      if arch.nil?
        arch = 'amd64'
      end
    end

    return "#{platform}-#{version}-#{arch}"
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
