require 'set'

# Data plus utilities surrounding platforms that the automation in this repo
# explicitly supports
module Pkg::Platforms # rubocop:disable Metrics/ModuleLength
  module_function

  # Each element in this hash
  PLATFORM_INFO = {
    'aix' => {
      '5.3' => { architectures: ['power'], repo: false, package_format: 'rpm' },
      '6.1' => { architectures: ['power'], repo: false, package_format: 'rpm' },
      '7.1' => { architectures: ['power'], repo: false, package_format: 'rpm' }
    },

    'cisco-wrlinux' => {
      '5' => { architectures: ['x86_64'], repo: true, package_format: 'rpm', signature_format: 'v4' },
      '7' => { architectures: ['x86_64'], repo: true, package_format: 'rpm', signature_format: 'v4' }
    },

    'cumulus' => {
      '2.2' => { codename: 'cumulus', architectures: ['amd64'], repo: true, package_format: 'deb' }
    },

    'debian' => {
      '7' => { codename: 'wheezy', architectures: ['i386', 'amd64'], repo: true, package_format: 'deb' },
      '8' => { codename: 'jessie', architectures: ['i386', 'amd64', 'powerpc'], repo: true, package_format: 'deb' },
      '9' => { codename: 'stretch', architectures: ['i386', 'amd64'], repo: true, package_format: 'deb' }
    },

    'el' => {
      '5' => { architectures: ['i386', 'x86_64'], repo: true, package_format: 'rpm', signature_format: 'v3' },
      '6' => { architectures: ['i386', 'x86_64', 's390x'], repo: true, package_format: 'rpm', signature_format: 'v4' },
      '7' => { architectures: ['x86_64', 's390x'], repo: true, package_format: 'rpm', signature_format: 'v4' }
    },

    'eos' => {
      '4' => { architectures: ['i386'], repo: false, package_format: 'swix' }
    },

    'fedora' => {
      'f24' => { architectures: ['i386', 'x86_64'], repo: true, package_format: 'rpm', signature_format: 'v4' },
      'f25' => { architectures: ['i386', 'x86_64'], repo: true, package_format: 'rpm', signature_format: 'v4' }
    },

    'huaweios' => {
      '6' => { codename: 'huaweios', architectures: ['powerpc'], repo: true, package_format: 'deb' }
    },

    'osx' => {
      '10.10' => { architectures: ['x86_64'], repo: false, package_format: 'dmg' },
      '10.11' => { architectures: ['x86_64'], repo: false, package_format: 'dmg' },
      '10.12' => { architectures: ['x86_64'], repo: false, package_format: 'dmg' }
    },

    'sles' => {
      '11' => { architectures: ['i386', 'x86_64', 's390x'], repo: true, package_format: 'rpm', signature_format: 'v3' },
      '12' => { architectures: ['x86_64', 's390x'], repo: true, package_format: 'rpm', signature_format: 'v4' }
    },

    'solaris' => {
      '10' => { architectures: ['i386', 'sparc'], repo: false, package_format: 'svr4' },
      '11' => { architectures: ['i386', 'sparc'], repo: false, package_format: 'ips' }
    },

    'ubuntu' => {
      '14.04' => { codename: 'trusty', architectures: ['i386', 'amd64'], repo: true, package_format: 'deb' },
      '16.04' => { codename: 'xenial', architectures: ['i386', 'amd64', 'ppc64el'], repo: true, package_format: 'deb' },
      '16.10' => { codename: 'yakkety', architectures: ['i386', 'amd64'], repo: true, package_format: 'deb' }
    },

    'windows' => {
      '2012' => { architectures: ['x86', 'x64'], repo: false, package_format: 'msi' }
    }
  }.freeze

  # @private List platforms that use a given package format
  # @param format [String] The name of the packaging format to filter on
  # @return [Array] An Array of Strings, containing all platforms that
  #   use <format> for their packages
  def by_package_format(format)
    PLATFORM_INFO.keys.select do |key|
      formats = PLATFORM_INFO[key].values.collect { |v| v[:package_format] }
      formats.include? format
    end
  end

  # @return [Array] An Array of Strings, containing all of the package
  #   formats defined in Pkg::Platforms
  def formats
    fmts = PLATFORM_INFO.flat_map do |_, p|
      p.collect do |_, r|
        r[:package_format]
      end
    end
    fmts.to_set.sort
  end

  # @return [Array] An array of Strings, containing all of the supported
  #   platforms as defined in PLATFORM_INFO
  def supported_platforms
    PLATFORM_INFO.keys
  end

  # @return [Array] An Array of Strings, containing all the supported
  #   versions for the given platform
  def versions_for_platform(platform)
    PLATFORM_INFO[platform].keys
  end

  # @param platform [String] The platform to list all codenames for
  # @return [Array] An Array of Strings, containing all of the codenames
  #   defined for a given Platform
  def codenames(platform)
    releases = send("by_#{platform}".to_s).flat_map do |p|
      PLATFORM_INFO[p].values.collect { |r| r[:codename] }
    end
    releases.sort
  end

  # Given a debian codename, return the platform and version it corresponds to
  def codename_to_platform_version(codename)
    PLATFORM_INFO.each do |platform, platform_versions|
      platform_versions.each do |version, info|
        return [platform, version] if codename == info[:codename]
      end
    end
  end

  # Given a debian platform and version, return the codename that corresponds to
  # the set
  def codename_for_platform_version(platform, version)
    PLATFORM_INFO[platform][version][:codename]
  end

  # Given a debian codename, return the arches that we build for that codename
  def arches_for_codename(codename)
    platform, version = codename_to_platform_version(codename)
    PLATFORM_INFO[platform][version][:architectures]
  end

  # Given a codename, return an array of associated tags
  def codename_to_tags(codename)
    platform_tags = []
    platform, version = codename_to_platform_version(codename)
    arches_for_codename(codename).each do |arch|
      platform_tags << "#{platform}-#{version}-#{arch}"
    end
    platform_tags
  end

  # Given a platform and version, return the arches that we build for that
  # platform
  def arches_for_platform_version(platform, version)
    PLATFORM_INFO[platform][version][:architectures]
  end

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
    platform, version, = parse_platform_tag(platform_tag)
    PLATFORM_INFO[platform][version]
  end

  # rubocop:disable Style/GuardClause
  def parse_platform_tag(platform_tag)
    platform, version, arch = platform_tag.match(/^(.*)-(.*)-(.*)$/).captures
    if PLATFORM_INFO.key?(platform) && PLATFORM_INFO[platform].key?(version) && PLATFORM_INFO[platform][version][:architectures].include?(arch)
      [platform, version, arch]
    else
      raise "#{platform_tag} isn't a valid platform tag. Perhaps it hasn't been defined yet?"
    end
  end

  def get_attribute(platform_tag, attribute_name)
    info = platform_lookup(platform_tag)
    raise "#{platform_tag} doesn't have information about #{attribute_name} available" unless info.key?(attribute_name)
    info[attribute_name]
  end

  def package_format_for_tag(platform_tag)
    platform, version = parse_platform_tag(platform_tag)
    Pkg::Platforms::PLATFORM_INFO[platform][version][:package_format]
  end

  # @method by_deb
  # @return [Array] An Array of Strings, containing all platforms
  #   that use .deb packages
  # Helper meta-method to return all platforms that use .deb packages
  # @scope class

  # @method by_rpm
  # @return [Array] An Array of Strings, containing all platforms
  #   that use .rpm packages
  # Helper meta-method to return all platforms that use .rpm packages
  # @scope class
  formats.each do |format|
    type = "by_#{format}".to_sym
    define_method(type) do
      by_package_format format
    end
  end

  private :by_package_format
end
