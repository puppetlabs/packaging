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
    platform = Pkg::Platforms.supported_platforms.find { |p| path =~ /(\/|\.)#{p}[^\.]/ }
    if platform == 'windows'
      version = '2012'
      arch = Pkg::Platforms.arches_for_platform_version(platform, version).find { |a| path.include?(a) }
      if arch.nil?
        arch = Pkg::Platforms.arches_for_platform_version(platform, version)[0]
      end
    elsif !platform.nil?
      version = Pkg::Platforms.versions_for_platform(platform).find { |v| path =~ /#{platform}(\/|-)?#{v}/ }
      unless version.nil?
        arch = Pkg::Platforms.arches_for_platform_version(platform, version).find { |a| path.include?(a) }
        if arch.nil?
          arch = Pkg::Platforms.arches_for_platform_version(platform, version)[0]
        end
      end
    end
    # if we didn't find a platform or a version, probably a codename
    if platform.nil? || version.nil?
      codename = Pkg::Platforms.codenames('deb').find { |c| path =~ /\/#{c}/ }
      fail "I can't find a codename or platform in #{path}, teach me?" if codename.nil?
      platform, version = Pkg::Platforms.codename_to_platform_version(codename)
      fail "I can't find a platform and version from #{codename}, teach me?" if platform.nil? || version.nil?
      arch = Pkg::Platforms.arches_for_platform_version(platform, version).find { |a| path.include?(a) }
      if arch.nil?
        arch = Pkg::Platforms.arches_for_codename(codename)[0]
      end
    end

    return "#{platform}-#{version}-#{arch}"
  end

  # Assign repo name
  # If we are shipping development/beta/non-final packages, they should be
  # shipped to the development/beta/non-final repo, if there is one defined.
  # Otherwise, default to the final repo name. We use this for more than just
  # shipping to the final repos, so we need this to not fail.
  def repo_name
    if Pkg::Util::Version.final?
      Pkg::Config.repo_name || ""
    else
      if Pkg::Config.nonfinal_repo_name
        Pkg::Config.nonfinal_repo_name
      else
        Pkg::Config.repo_name || ""
      end
    end
  end

  def link_name
    if Pkg::Util::Version.final?
      Pkg::Config.repo_link_target || nil
    else
      Pkg::Config.nonfinal_repo_link_target || nil
    end
  end

  def artifacts_base_path_and_link_path(platform_tag, path_prefix = 'artifacts')
    platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm'
      [File.join(path_prefix, repo_name), link_name.nil? ? nil : File.join(path_prefix, link_name)]
    when 'swix'
      [File.join(path_prefix, platform, repo_name), link_name.nil? ? nil : File.join(path_prefix, platform, link_name)]
    when 'deb'
      [File.join(path_prefix, Pkg::Platforms.get_attribute(platform_tag, :codename), repo_name),
       link_name.nil? ? nil : File.join(path_prefix, Pkg::Platforms.get_attribute(platform_tag, :codename), link_name)]
    when 'svr4', 'ips'
      [File.join(path_prefix, 'solaris', repo_name), link_name.nil? ? nil : File.join(path_prefix, 'solaris', link_name)]
    when 'dmg'
      [File.join(path_prefix, 'mac', repo_name), link_name.nil? ? nil : File.join(path_prefix, 'mac', link_name)]
    when 'msi'
      [File.join(path_prefix, 'windows', repo_name), link_name.nil? ? nil : File.join(path_prefix, 'windows', link_name)]
    else
      raise "Not sure where to find packages with a package format of '#{package_format}'"
    end
  end

  def artifacts_path(platform_tag, path_prefix = 'artifacts')
    base_path, _ = artifacts_base_path_and_link_path(platform_tag, path_prefix)
    platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm'
      File.join(base_path, platform, version, architecture)
    when 'swix'
      File.join(base_path, version, architecture)
    when 'deb'
      base_path
    when 'svr4', 'ips'
      File.join(base_path, version)
    when 'dmg'
      File.join(base_path, version, architecture)
    when 'msi'
      base_path
    else
      raise "Not sure where to find packages with a package format of '#{package_format}'"
    end
  end

  def repo_path(platform_tag)
    platform, version, arch = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm', 'swix'
      File.join('repos', repo_name, platform, version, arch)
    when 'deb'
      File.join('repos', 'apt', Pkg::Platforms.get_attribute(platform_tag, :codename), 'pool', repo_name)
    when 'svr4', 'ips'
      File.join('repos', 'solaris', repo_name, version)
    when 'dmg'
      File.join('repos', 'mac', repo_name, version, arch)
    when 'msi'
      File.join('repos', 'windows', repo_name)
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
