require 'packaging/platforms'

module Pkg::Util::Platform
  include Pkg::Platforms
  class << self
    PLATFORM_INFO = Pkg::Platforms::PLATFORM_INFO

    # Returns an array of all currently valid platform tags
    def platform_tags
      tags = []
      PLATFORM_INFO.each do |platform, platform_versions|
        platform_versions.each do |version, info|
          info[:architectures].each do |arch|
            tags << "#{platform}-#{version}-#{arch}"
          end
        end
      end
      tags
    end

    def platform_lookup(platform_tag)
      platform, version, _ = parse_platform_tag(platform_tag)
      return PLATFORM_INFO[platform][version]
    end

    def parse_platform_tag(platform_tag)
      platform, version, arch = platform_tag.match(/^(.*)-(.*)-(.*)$/).captures
      if PLATFORM_INFO.has_key?(platform) && PLATFORM_INFO[platform].has_key?(version) && PLATFORM_INFO[platform][version][:architectures].include?(arch)
        [platform, version, arch]
      else
        fail "#{platform_tag} isn't a valid platform tag. Perhaps it hasn't been defined yet?"
      end
    end

    def get_attribute(platform_tag, attribute_name)
      info = platform_lookup(platform_tag)
      if info.has_key?(attribute_name.to_sym)
        info[attribute_name.to_sym]
      else
        fail "#{platform_tag} doesn't have information about #{attribute_name} available"
      end
    end

    def artifacts_path(platform_tag, package_url = nil)
      platform, version = parse_platform_tag(platform_tag)
      package_format = PLATFORM_INFO[platform][version][:package_format]

      case package_format
      when 'rpm', 'swix'
        # el/7/PC1/x86_64 for example
        File.join('artifacts', platform, version)
      when 'deb'
        File.join('artifacts', 'deb', get_attribute(platform_tag, :codename))
      when 'svr4', 'ips'
        # solaris/10/PC1 for example
        File.join('artifacts', 'solaris', version)
      when 'dmg'
        # We don't consistently ship OSX artifacts to the same path
        # vanagon ships things under a version number, and standard
        # packaging excludes the version number. We should fix that, but in
        # the interim we can check whether or not the versioned path exists
        # and fail back to the unversioned path if needed.
        version_path = File.join('artifacts', 'apple', version)
        if package_url.nil?
          version_path
        else
          code = Pkg::Util::Net.uri_status_code("#{package_url}/#{version_path}")
          if code == '200'
            version_path
          else
            File.join('artifacts', 'apple')
          end
        end
      when 'msi'
        File.join('artifacts', 'windows')
      else
        fail "Not sure where to find packages with a package format of '#{package_format}'"
      end
    end

    def repo_path(platform_tag)
      platform, version, arch = parse_platform_tag(platform_tag)
      package_format = PLATFORM_INFO[platform][version][:package_format]

      case package_format
      when 'rpm', 'swix'
        # el/7/PC1/x86_64 for example
        File.join('repos', platform, version, '**', arch)
      when 'deb'
        File.join('repos', 'apt', get_attribute(platform_tag, :codename))
      when 'svr4', 'ips'
        # solaris/10/PC1 for example
        File.join('repos', 'solaris', version, '**')
      when 'dmg'
        File.join('repos', 'apple', version, '**', arch)
      when 'msi'
        File.join('repos', 'windows')
      else
        fail "Not sure what to do with a package format of '#{package_format}'"
      end
    end

    def repo_config_path(platform_tag)
      platform, version, _ = parse_platform_tag(platform_tag)
      package_format = PLATFORM_INFO[platform][version][:package_format]

      case package_format
      when 'rpm'
        # rpm/pl-puppet-agent-1.2.5-el-5-i386.repo for example
        File.join('repo_configs', 'rpm', "*#{platform_tag}*.repo")
      when 'deb'
        # deb/pl-puppet-agent-1.2.5-jessie.list
        File.join('repo_configs', 'deb', "*#{get_attribute(platform_tag, :codename)}*.list")
      when 'msi', 'swix', 'dmg', 'svr4', 'ips'
        nil
      else
        fail "Not sure what to do with a package format of '#{package_format}'"
      end
    end
  end
end
