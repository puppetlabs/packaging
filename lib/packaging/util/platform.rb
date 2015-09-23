require 'packaging/config/platforms'

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
      if PLATFORM_INFO[platform][version][:architectures].include?(arch)
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
