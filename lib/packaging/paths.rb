# Utilities surrounding the appropriate paths associated with a platform
# This includes both reporting the correct path and divining the platform
# tag associated with a variety of paths
#
# rubocop:disable Metrics/ModuleLength
module Pkg::Paths
  include Pkg::Platforms

  module_function

  def arch_from_artifact_path(platform, version, path)
    arches = Pkg::Platforms.arches_for_platform_version(platform, version)

    # First check if it's a source package
    source_formats = Pkg::Platforms.get_attribute_for_platform_version(platform, version, :source_package_formats)
    if source_formats.find { |fmt| path =~ /#{fmt}$/ }
      return Pkg::Platforms.get_attribute_for_platform_version(platform, version, :source_architecture)
    end
    arches.find { |a| path.include?(a) } || arches[0]
  rescue
    arches.find { |a| path.include?(a) } || arches[0]
  end

  # Given a path to an artifact, divine the appropriate platform tag associated
  # with the artifact and path
  def tag_from_artifact_path(path)
    platform = Pkg::Platforms.supported_platforms.find { |p| path =~ /(\/|\.)#{p}[^\.]/ }
    codename = Pkg::Platforms.codenames.find { |c| path =~ /\/#{c}/ }

    if codename
      platform, version = Pkg::Platforms.codename_to_platform_version(codename)
    end

    version = '2012' if platform == 'windows'

    version ||= Pkg::Platforms.versions_for_platform(platform).find { |v| path =~ /#{platform}(\/|-)?#{v}/ }

    arch = arch_from_artifact_path(platform, version, path)

    return "#{platform}-#{version}-#{arch}"
  rescue
    fmt = Pkg::Platforms.all_supported_package_formats.find { |ext| path =~ /#{ext}$/ }

    # We need to make sure this is actually a file, and not simply a path
    file_ext = File.extname(path)

    # Fail if we do not have a file extension or if that file extension is one
    # that is platform specific
    raise "Cannot determine tag from #{path}" if fmt || file_ext.empty?

    # Return nil otherwise, assuming that is a file type that is not tied to a
    # specific platform
    return nil
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

  # TODO: please please please clean this up
  # This is so terrible. I really dislike it. But in order to maintain backward
  # compatibility, we need to maintain these path differences between PC1 and
  # everything else. Once we stop shipping things to PC1, we can remove all the
  # PC1 specific cases. That's likely to not happen until the current LTS
  # (2016.4) is EOL'd. Hopefully also we do not choose to further change these
  # path structures, as it is no bueno.
  # --MAS 2017-08-16
  def artifacts_base_path_and_link_path(platform_tag, path_prefix = 'artifacts')
    platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm'
      if repo_name == 'PC1'
        [File.join(path_prefix, platform, version, repo_name), nil]
      else
        [File.join(path_prefix, repo_name), link_name.nil? ? nil : File.join(path_prefix, link_name)]
      end
    when 'swix'
      if repo_name == 'PC1'
        [File.join(path_prefix, platform, version, repo_name), nil]
      else
        [File.join(path_prefix, platform, repo_name), link_name.nil? ? nil : File.join(path_prefix, platform, link_name)]
      end
    when 'deb'
      [File.join(path_prefix, Pkg::Platforms.get_attribute(platform_tag, :codename), repo_name),
       link_name.nil? ? nil : File.join(path_prefix, Pkg::Platforms.get_attribute(platform_tag, :codename), link_name)]
    when 'svr4', 'ips'
      if repo_name == 'PC1'
        [File.join(path_prefix, 'solaris', repo_name, version), nil]
      else
        [File.join(path_prefix, 'solaris', repo_name), link_name.nil? ? nil : File.join(path_prefix, 'solaris', link_name)]
      end
    when 'dmg'
      if repo_name == 'PC1'
        [File.join(path_prefix, 'mac', version, repo_name), nil]
      else
        [File.join(path_prefix, 'mac', repo_name), link_name.nil? ? nil : File.join(path_prefix, 'mac', link_name)]
      end
    when 'msi'
      if repo_name == 'PC1'
        [File.join(path_prefix, 'windows'), nil]
      else
        [File.join(path_prefix, 'windows', repo_name), link_name.nil? ? nil : File.join(path_prefix, 'windows', link_name)]
      end
    else
      raise "Not sure where to find packages with a package format of '#{package_format}'"
    end
  end

  # TODO: please please please clean this up
  # This is so terrible. I really dislike it. But in order to maintain backward
  # compatibility, we need to maintain these path differences between PC1 and
  # everything else. Once we stop shipping things to PC1, we can remove all the
  # PC1 specific cases. That's likely to not happen until the current LTS
  # (2016.4) is EOL'd. Hopefully also we do not choose to further change these
  # path structures, as it is no bueno.
  # --MAS 2017-08-16
  def artifacts_path(platform_tag, path_prefix = 'artifacts')
    base_path, _ = artifacts_base_path_and_link_path(platform_tag, path_prefix)
    platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm'
      if repo_name == 'PC1'
        File.join(base_path, architecture)
      else
        File.join(base_path, platform, version, architecture)
      end
    when 'swix'
      if repo_name == 'PC1'
        File.join(base_path, architecture)
      else
        File.join(base_path, version, architecture)
      end
    when 'deb'
      base_path
    when 'svr4', 'ips'
      if repo_name == 'PC1'
        base_path
      else
        File.join(base_path, version)
      end
    when 'dmg'
      if repo_name == 'PC1'
        File.join(base_path, architecture)
      else
        File.join(base_path, version, architecture)
      end
    when 'msi'
      base_path
    else
      raise "Not sure where to find packages with a package format of '#{package_format}'"
    end
  end

  def repo_path(platform_tag, legacy = false)
    repo_target = repo_name
    repo_target = Pkg::Config.repo_name if legacy
    platform, version, arch = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm', 'swix'
      if legacy
        File.join('repos', platform, version, repo_target, arch)
      else
        File.join('repos', repo_target, platform, version, arch)
      end
    when 'deb'
      File.join('repos', 'apt', Pkg::Platforms.get_attribute(platform_tag, :codename), 'pool', repo_target)
    when 'svr4', 'ips'
      File.join('repos', 'solaris', repo_target, version)
    when 'dmg'
      File.join('repos', 'mac', repo_target, version, arch)
    when 'msi'
      File.join('repos', 'windows', repo_target)
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
