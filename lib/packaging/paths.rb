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
    arches.find { |a| path.include?(package_arch(platform, a)) } || arches[0]
  rescue
    arches.find { |a| path.include?(package_arch(platform, a)) } || arches[0]
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

  # Construct a platform-dependent symlink target path.
  def construct_base_path(path_data)
    package_format = path_data[:package_format]
    prefix = path_data[:prefix]
    is_nonfinal = path_data[:is_nonfinal]
    platform_name = path_data[:platform_name]
    platform_tag = path_data[:platform_tag]

    repo_name = Pkg::Config.repo_name

    case package_format
    when 'deb'
      debian_code_name = Pkg::Platforms.get_attribute(platform_tag, :codename)

      # In puppet7 and beyond, we moved the repo_name to the top to allow each
      # puppet major release to have its own apt repo.
      if %w(FUTURE-puppet7 FUTURE-puppet7-nightly).include? repo_name
        return File.join(prefix, apt_repo_name(is_nonfinal), debian_code_name)
      end

      # For puppet6 and prior
      return File.join(prefix, debian_code_name, apt_repo_name(is_nonfinal))
    when 'dmg'
      return File.join(prefix, 'mac', repo_name(is_nonfinal))
    when 'msi'
      return File.join(prefix, platform_name, repo_name(is_nonfinal))
    when 'rpm'
      return File.join(prefix, yum_repo_name(is_nonfinal))
    when 'swix'
      return File.join(prefix, platform_name, repo_name(is_nonfinal))
    when 'svr4', 'ips'
      return File.join(prefix, 'solaris', repo_name(is_nonfinal))
    else
      raise "Error: Unknown package format '#{package_format}'"
    end
  end

  # Construct a platform-dependent link path
  def construct_link_path(path_data)
    package_format = path_data[:package_format]
    prefix = path_data[:prefix]
    platform_name = path_data[:platform_name]
    platform_tag = path_data[:platform_tag]
    link = path_data[:link]

    return nil if link.nil?

    case package_format
    when 'rpm'
      return File.join(prefix, link)
    when 'swix'
      return File.join(prefix, platform_name, link)
    when 'deb'
      debian_code_name = Pkg::Platforms.get_attribute(platform_tag, :codename)
      return File.join(prefix, debian_code_name, link)
    when 'svr4', 'ips'
      return File.join(prefix, 'solaris', link)
    when 'dmg'
      return File.join(prefix, 'mac', link)
    when 'msi'
      return File.join(prefix, platform_name, link)
    else
      raise "Error: Unknown package format '#{package_format}'"
    end
  end

  # Given platform information, create symlink target (base_path) and link path in the
  # form of a 2-element array
  def artifacts_base_path_and_link_path(platform_tag, prefix = 'artifacts', is_nonfinal = false)
    platform_name, _ = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)

    path_data = {
      is_nonfinal: is_nonfinal,
      link: link_name(is_nonfinal),
      package_format: package_format,
      platform_name: platform_name,
      platform_tag: platform_tag,
      prefix: prefix
    }

    return [
      construct_base_path(path_data),
      construct_link_path(path_data)
    ]
  end

  def artifacts_path(platform_tag, path_prefix = 'artifacts', nonfinal = false)
    base_path, _ = artifacts_base_path_and_link_path(platform_tag, path_prefix, nonfinal)
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

  def remote_repo_base(platform_tag = nil, nonfinal: false, package_format: nil)
    if platform_tag.nil? && package_format.nil?
      raise "Pkg::Paths.remote_repo_base must have `platform_tag` or `package_format` specified."
    end

    package_format ||= Pkg::Platforms.package_format_for_tag(platform_tag)

    repo_base = case package_format
    when 'rpm'
      nonfinal ? Pkg::Config.nonfinal_yum_repo_path : Pkg::Config.yum_repo_path
    when 'deb'
      nonfinal ? Pkg::Config.nonfinal_apt_repo_path : Pkg::Config.apt_repo_path
    when 'dmg'
      nonfinal ? Pkg::Config.nonfinal_dmg_path : Pkg::Config.dmg_path
    when 'swix'
      nonfinal ? Pkg::Config.nonfinal_swix_path : Pkg::Config.swix_path
    when 'msi'
      nonfinal ? Pkg::Config.nonfinal_msi_path : Pkg::Config.msi_path
    else
      raise "Can't determine remote repo base path for package format '#{package_format}'."
    end

    # normalize the path for things shipping to the downloads server
    if repo_base.match(/^\/opt\/downloads\/\w+$/)
      repo_base = '/opt/downloads'
    end
    repo_base
  end

  # This is where deb packages end up after freight repo updates
  def apt_package_base_path(platform_tag, repo_name, project, nonfinal = false)
    unless Pkg::Platforms.package_format_for_tag(platform_tag) == 'deb'
      fail "Can't determine path for non-debian platform #{platform_tag}."
    end

    platform, version, _ = Pkg::Platforms.parse_platform_tag(platform_tag)
    code_name = Pkg::Platforms.codename_for_platform_version(platform, version)
    remote_repo_path = remote_repo_base(platform_tag, nonfinal: nonfinal)

    # In puppet7 and beyond, we moved the puppet major version to near the top to allow each
    # puppet major release to have its own apt repo, for example:
    # /opt/repository/apt/puppet7/pool/bionic/p/puppet-agent
    if %w(FUTURE-puppet7 FUTURE-puppet7-nightly).include? repo_name
      return File.join(remote_repo_path, repo_name, 'pool', code_name, project[0], project)
    end

    # For repos prior to puppet7, the puppet version was part of the repository
    # For example: /opt/repository/apt/pool/bionic/puppet6/p/puppet-agent
    if %w(puppet7 puppet7-nightly
          puppet6 puppet6-nightly
          puppet5 puppet5-nightly
          puppet).include? repo_name
      return File.join(remote_repo_path, 'pool', code_name, repo_name, project[0], project)
    end

    raise "Error: Cannot determine apt_package_base_path for repo: \"#{repo_name}\"."
  end

  def release_package_link_path(platform_tag, nonfinal = false)
    platform, version, _ = Pkg::Platforms.parse_platform_tag(platform_tag)
    package_format = Pkg::Platforms.package_format_for_tag(platform_tag)
    case package_format
    when 'rpm'
      return File.join(remote_repo_base(platform_tag, nonfinal: nonfinal),
                       "#{repo_name(nonfinal)}-release-#{platform}-#{version}.noarch.rpm")
    when 'deb'
      codename = Pkg::Platforms.codename_for_platform_version(platform, version)
      return File.join(remote_repo_base(platform_tag, nonfinal: nonfinal),
                       "#{repo_name(nonfinal)}-release-#{codename}.deb")
    else
      warn "No release packages for package format '#{package_format}', skipping."
      return nil
    end
  end

  def debian_component_from_path(path)
    # substitute '.' and '/' since those aren't valid characters for debian components
    matches = path.match(/(\d+\.\d+|master|main)\/(\w+)/)
    regex_for_substitution = /[\.\/]/
    fail "Error: Could not determine Debian Component from path #{path}" if matches.nil?
    base_component = matches[1]
    component_qualifier = matches[2]
    full_component = "#{base_component}/#{component_qualifier}"
    unless regex_for_substitution.nil?
      base_component.gsub!(regex_for_substitution, '_')
      full_component.gsub!(regex_for_substitution, '_')
    end
    return base_component if component_qualifier == 'repos'
    return full_component
  end

  #for ubuntu-20.04-aarch64, debian package architecture is arm64
  def package_arch(platform, arch)
    if platform == 'ubuntu' && arch == 'aarch64'
      return 'arm64'
    end
    arch
  end

  private :package_arch

end
