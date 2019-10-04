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
    platform = 'windowsfips' if path =~ /windowsfips/

    codename = Pkg::Platforms.codenames.find { |c| path =~ /\/#{c}/ }

    if codename
      platform, version = Pkg::Platforms.codename_to_platform_version(codename)
    end

    version = '2012' if platform =~ /^windows.*$/

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
  def repo_name(nonfinal = false)
    if nonfinal && Pkg::Config.nonfinal_repo_name
      Pkg::Config.nonfinal_repo_name
    elsif nonfinal
      fail "Nonfinal is set to true but Pkg::Config.nonfinal_repo_name is unset!"
    else
      Pkg::Config.repo_name || ""
    end
  end

  # Method to determine if files should be shipped to legacy or current path
  # structures. Any repo name matching /^puppet/ is a current repo, everything
  # else is should be shipped to legacy paths.
  #
  # @param repo_name The repo name to check
  def is_legacy_repo?(repo_name)
    repo_name !~ /^puppet/
  end

  # Method to determine the yum repo name. Maintains compatibility with legacy
  # projects, where `Pkg::Config.yum_repo_name` is set instead of
  # `Pkg::Config.repo_name`. Defaults to 'products' if nothing is set.
  def yum_repo_name(nonfinal = false)
    if nonfinal && Pkg::Config.nonfinal_repo_name
      return Pkg::Config.nonfinal_repo_name
    elsif nonfinal
      fail "Nonfinal is set to true but Pkg::Config.nonfinal_repo_name is unset!"
    end

    return Pkg::Config.repo_name || Pkg::Config.yum_repo_name || 'products'
  end

  # Method to determine the apt repo name. Maintains compatibility with legacy
  # projects, where `Pkg::Config.apt_repo_name` is set instead of
  # `Pkg::Config.repo_name`. Defaults to 'main' if nothing is set.
  def apt_repo_name(nonfinal = false)
    if nonfinal && Pkg::Config.nonfinal_repo_name
      return Pkg::Config.nonfinal_repo_name
    elsif nonfinal
      fail "Nonfinal is set to true but Pkg::Config.nonfinal_repo_name is unset!"
    end

    return Pkg::Config.repo_name || Pkg::Config.apt_repo_name || 'main'
  end

  def link_name(nonfinal = false)
    return Pkg::Config.nonfinal_repo_link_target if nonfinal
    return Pkg::Config.repo_link_target
  end

  # TODO: please please please clean this up
  # This is so terrible. I really dislike it. But in order to maintain backward
  # compatibility, we need to maintain these path differences between PC1 and
  # everything else. Once we stop shipping things to PC1, we can remove all the
  # PC1 specific cases. That's likely to not happen until the current LTS
  # (2016.4) is EOL'd. Hopefully also we do not choose to further change these
  # path structures, as it is no bueno.
  # --MAS 2017-08-16
  def artifacts_base_path_and_link_path(platform_tag, path_prefix = 'artifacts', nonfinal = false)
    platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm'
      if is_legacy_repo?(yum_repo_name(nonfinal))
        [File.join(path_prefix, platform, version, yum_repo_name(nonfinal)), nil]
      else
        [File.join(path_prefix, yum_repo_name(nonfinal)), link_name(nonfinal).nil? ? nil : File.join(path_prefix, link_name(nonfinal))]
      end
    when 'swix'
      if is_legacy_repo?(repo_name(nonfinal))
        [File.join(path_prefix, platform, version, repo_name(nonfinal)), nil]
      else
        [File.join(path_prefix, platform, repo_name(nonfinal)), link_name(nonfinal).nil? ? nil : File.join(path_prefix, platform, link_name(nonfinal))]
      end
    when 'deb'
      [File.join(path_prefix, Pkg::Platforms.get_attribute(platform_tag, :codename), apt_repo_name(nonfinal)),
       link_name(nonfinal).nil? ? nil : File.join(path_prefix, Pkg::Platforms.get_attribute(platform_tag, :codename), link_name(nonfinal))]
    when 'svr4', 'ips'
      if is_legacy_repo?(repo_name(nonfinal))
        [File.join(path_prefix, 'solaris', repo_name(nonfinal), version), nil]
      else
        [File.join(path_prefix, 'solaris', repo_name(nonfinal)), link_name(nonfinal).nil? ? nil : File.join(path_prefix, 'solaris', link_name(nonfinal))]
      end
    when 'dmg'
      if is_legacy_repo?(repo_name(nonfinal))
        [File.join(path_prefix, 'mac', version, repo_name(nonfinal)), nil]
      else
        [File.join(path_prefix, 'mac', repo_name(nonfinal)), link_name(nonfinal).nil? ? nil : File.join(path_prefix, 'mac', link_name(nonfinal))]
      end
    when 'msi'
      if is_legacy_repo?(repo_name(nonfinal))
        [File.join(path_prefix, 'windows'), nil]
      else
        [File.join(path_prefix, platform, repo_name(nonfinal)), link_name(nonfinal).nil? ? nil : File.join(path_prefix, platform, link_name(nonfinal))]
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
  def artifacts_path(platform_tag, path_prefix = 'artifacts', nonfinal = false)
    base_path, _ = artifacts_base_path_and_link_path(platform_tag, path_prefix, nonfinal)
    platform, version, architecture = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm'
      if is_legacy_repo?(yum_repo_name(nonfinal))
        File.join(base_path, architecture)
      else
        File.join(base_path, platform, version, architecture)
      end
    when 'swix'
      if is_legacy_repo?(repo_name(nonfinal))
        File.join(base_path, architecture)
      else
        File.join(base_path, version, architecture)
      end
    when 'deb'
      base_path
    when 'svr4', 'ips'
      if is_legacy_repo?(repo_name(nonfinal))
        base_path
      else
        File.join(base_path, version)
      end
    when 'dmg'
      if is_legacy_repo?(repo_name(nonfinal))
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

  def repo_path(platform_tag, options = { :legacy => false, :nonfinal => false })
    repo_target = repo_name(options[:nonfinal])
    # in legacy packaging methods, there was no consistent way to determine the
    # repo name. There were separate variables for apt_repo_name and
    # yum_repo_name. At times, either or both of these were unset, and they had
    # different defaults. So, for legacy automation we need to just use a splat
    # and globbing to find our packages.
    repo_target = '**' if options[:legacy]
    platform, version, arch = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    case package_format
    when 'rpm', 'swix'
      if options[:legacy]
        File.join('repos', platform, version, repo_target, arch)
      else
        File.join('repos', repo_target, platform, version, arch)
      end
    when 'deb'
      File.join('repos', 'apt', Pkg::Platforms.get_attribute(platform_tag, :codename), 'pool', repo_target)
    when 'svr4', 'ips'
      if options[:legacy]
        File.join('repos', 'solaris', version, repo_target)
      else
        File.join('repos', 'solaris', repo_target, version)
      end
    when 'dmg'
      if options[:legacy]
        File.join('repos', 'apple', version, repo_target, arch)
      else
        File.join('repos', 'mac', repo_target, version, arch)
      end
    when 'msi'
      if options[:legacy]
        File.join('repos', 'windows')
      else
        File.join('repos', platform, repo_target)
      end
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

  def remote_repo_base(platform_tag, nonfinal = false)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)
    case package_format
    when 'rpm'
      nonfinal ? Pkg::Config.nonfinal_yum_repo_path : Pkg::Config.yum_repo_path
    when 'deb'
      nonfinal ? Pkg::Config.nonfinal_apt_repo_path : Pkg::Config.apt_repo_path
    else
      raise "Can't determine remote repo base path for package format '#{package_format}'."
    end
  end

  # This is where deb packages end up after freight repo updates
  def apt_package_base_path(platform_tag, repo_name, project, nonfinal = false)
    fail "Can't determine path for non-debian platform #{platform_tag}." unless Pkg::Platforms.package_format_for_tag(platform_tag) == 'deb'
    platform, version, _ = Pkg::Platforms.parse_platform_tag(platform_tag)
    codename = Pkg::Platforms.codename_for_platform_version(platform, version)
    return File.join(remote_repo_base(platform_tag, nonfinal), 'pool', codename, repo_name, project[0], project)
  end

  def release_package_link_path(platform_tag, nonfinal = false)
    platform, version, arch = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)
    case package_format
    when 'rpm'
      return File.join(remote_repo_base(platform_tag, nonfinal), "#{repo_name(nonfinal)}-release-#{platform}-#{version}.noarch.rpm")
    when 'deb'
      codename = Pkg::Platforms.codename_for_platform_version(platform, version)
      return File.join(remote_repo_base(platform_tag, nonfinal), "#{repo_name(nonfinal)}-release-#{codename}.deb")
    else
      warn "No release packages for package format '#{package_format}', skipping . . ."
      return nil
    end
  end

  def two_digit_pe_version_from_path(path)
    matches = path.match(/\d+\.\d+/)
    fail "Error: Could not determine PE version from path #{path}" if matches.nil?
    return matches[0]
  end
end
