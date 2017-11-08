require 'set'

# Data plus utilities surrounding platforms that the automation in this repo
# explicitly supports
module Pkg::Platforms # rubocop:disable Metrics/ModuleLength
  module_function

  DEBIAN_SOURCE_FORMATS = ['debian.tar.gz', 'orig.tar.gz', 'dsc', 'changes']

  # Each element in this hash
  PLATFORM_INFO = {
    'aix' => {
      '6.1' => {
        architectures: ['power'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        repo: false,
      },
      '7.1' => {
        architectures: ['power'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        repo: false,
      }
    },

    'cisco-wrlinux' => {
      '5' => {
        architectures: ['x86_64'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      },
      '7' => {
        architectures: ['x86_64'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      }
    },

    'cumulus' => {
      '2.2' => {
        codename: 'cumulus',
        architectures: ['amd64'],
        source_architecture: 'source',
        package_format: 'deb',
        source_package_formats: DEBIAN_SOURCE_FORMATS,
        repo: true,
      }
    },

    'debian' => {
      '7' => {
        codename: 'wheezy',
        architectures: ['i386', 'amd64'],
        source_architecture: 'source',
        package_format: 'deb',
        source_package_formats: DEBIAN_SOURCE_FORMATS,
        repo: true,
      },
      '8' => {
        codename: 'jessie',
        architectures: ['i386', 'amd64', 'powerpc'],
        source_architecture: 'source',
        package_format: 'deb',
        source_package_formats: DEBIAN_SOURCE_FORMATS,
        repo: true,
      },
      '9' => {
        codename: 'stretch',
        architectures: ['i386', 'amd64'],
        source_architecture: 'source',
        package_format: 'deb',
        source_package_formats: DEBIAN_SOURCE_FORMATS,
        repo: true,
      }
    },

    'el' => {
      '5' => {
        architectures: ['i386', 'x86_64'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v3',
        repo: true,
      },
      '6' => {
        architectures: ['i386', 'x86_64', 's390x'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      },
      '7' => {
        architectures: ['x86_64', 's390x', 'ppc64le', 'aarch64'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      }
    },

    'eos' => {
      '4' => {
        architectures: ['i386'],
        package_format: 'swix',
        repo: false,
      }
    },

    'fedora' => {
      'f25' => {
        architectures: ['i386', 'x86_64'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      },
      'f26' => {
        architectures: ['x86_64'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      },
      '25' => {
        architectures: ['i386', 'x86_64'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      },
      '26' => {
        architectures: ['x86_64'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      },
    },

    'osx' => {
      '10.10' => {
        architectures: ['x86_64'],
        package_format: 'dmg',
        repo: false,
      },
      '10.11' => {
        architectures: ['x86_64'],
        package_format: 'dmg',
        repo: false,
      },
      '10.12' => {
        architectures: ['x86_64'],
        package_format: 'dmg',
        repo: false,
      }
    },

    'sles' => {
      '11' => {
        architectures: ['i386', 'x86_64', 's390x'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v3',
        repo: true,
      },
      '12' => {
        architectures: ['x86_64', 's390x', 'ppc64le'],
        source_architecture: 'SRPMS',
        package_format: 'rpm',
        source_package_formats: ['src.rpm'],
        signature_format: 'v4',
        repo: true,
      }
    },

    'solaris' => {
      '10' => {
        architectures: ['i386', 'sparc'],
        package_format: 'svr4',
        repo: false,
      },
      '11' => {
        architectures: ['i386', 'sparc'],
        package_format: 'ips',
        repo: false,
      }
    },

    'ubuntu' => {
      '14.04' => {
        codename: 'trusty',
        architectures: ['i386', 'amd64'],
        source_architecture: 'source',
        package_format: 'deb',
        source_package_formats: DEBIAN_SOURCE_FORMATS,
        repo: true,
      },
      '16.04' => {
        codename: 'xenial',
        architectures: ['i386', 'amd64', 'ppc64el'],
        source_architecture: 'source',
        package_format: 'deb',
        source_package_formats: DEBIAN_SOURCE_FORMATS,
        repo: true,
      },
    },

    'windows' => {
      '2012' => {
        architectures: ['x86', 'x64'],
        package_format: 'msi',
        repo: false,
      }
    }
  }.freeze

  # @return [Array] An array of Strings, containing all of the supported
  #   platforms as defined in PLATFORM_INFO
  def supported_platforms
    PLATFORM_INFO.keys
  end

  # @return [Array] An Array of Strings, containing all the supported
  #   versions for the given platform
  def versions_for_platform(platform)
    PLATFORM_INFO[platform].keys
  rescue
    raise "No information found for '#{platform}'"
  end

  # @param platform_tag [String] May be either the two or three unit string
  #   that corresponds to a platform in the form of platform-version or
  #   platform-version-arch.
  # @return [Array] An array of three elements: the platform name, the platform
  #   version, and the architecture. If the architecture was not included in
  #   the original platform tag, then nil is returned in place of the
  #   architecture
  def parse_platform_tag(platform_tag)
    platform_elements = platform_tag.split('-')

    # Look for platform. This is probably the only place where we have to look
    # for a combination of elements rather than a single element
    platform = (platform_elements & supported_platforms).first
    codename = (platform_elements & codenames).first

    # This is probably a bad assumption, but I'm assuming if we find a codename,
    # that's more reliable as it's less likely to give us a false match
    if codename
      platform, version = codename_to_platform_version(codename)
    end

    # There's a possibility that the platform name has a dash in it, in which
    # case, our assumption that it's an element of the above array is false,
    # since it would be a combination of elements in that array
    platform ||= supported_platforms.find { |p| platform_tag =~ /#{p}-/ }

    version ||= (platform_elements & versions_for_platform(platform)).first


    # For platform names with a dash in them, because everything is special
    supported_arches = arches_for_platform_version(platform, version)
    architecture = platform_tag.sub(/^(#{platform}-#{version}|#{codename})-?/, '')

    fail unless supported_arches.include?(architecture) || architecture.empty?
    return [platform, version, architecture]
  rescue
    raise "Could not verify that '#{platform_tag}' is a valid tag"
  end

  # @param platform_tag [String] May be either the two or three unit string
  #   that corresponds to a platform in the form of platform-version or
  #   platform-version-arch
  # @return [Hash] The hash of data associated with the given platform version
  def platform_lookup(platform_tag)
    platform, version, _ = parse_platform_tag(platform_tag)
    PLATFORM_INFO[platform][version]
  end

  # @param platform_tag [String] May be either the two or three unit string
  #   that corresponds to a platform in the form of platform-version or
  #   platform-version-arch
  # @param attribute_name [String, Symbol] The name of the requested attribute
  # @return [String, Array] the contents of the requested attribute
  def get_attribute(platform_tag, attribute_name)
    info = platform_lookup(platform_tag)
    raise "#{platform_tag} doesn't have information about #{attribute_name} available" unless info.key?(attribute_name)
    info[attribute_name]
  end

  def get_attribute_for_platform_version(platform, version, attribute_name)
    info = PLATFORM_INFO[platform][version]
    raise "#{platform_tag} doesn't have information about #{attribute_name} available" unless info.key?(attribute_name)
    info[attribute_name]
  end

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

  # @return [Array] An Array of Strings, containing all the package formats
  #   and source package formats defined in Pkg::Platforms
  def all_supported_package_formats
    fmts = formats
    source_fmts = PLATFORM_INFO.flat_map do |_, p|
      p.collect do |_, r|
        r[:source_package_formats]
      end
    end

    (fmts + source_fmts).flatten.compact.uniq.to_set.sort
  end

  # @param platform [String] Optional, the platform to list all codenames for.
  #   Defaults to 'deb'
  # @return [Array] An Array of Strings, containing all of the codenames
  #   defined for a given Platform
  def codenames(platform = 'deb')
    releases = by_package_format(platform).flat_map do |p|
      PLATFORM_INFO[p].values.collect { |r| r[:codename] }
    end
    releases.sort
  end

  # Given a debian codename, return the platform and version it corresponds to
  def codename_to_platform_version(codename)
    PLATFORM_INFO.each do |platform, platform_versions|
      platform_versions.each do |version, info|
        return [platform, version] if info[:codename] && codename == info[:codename]
      end
    end
    raise "Unable to find a platform and version for '#{codename}'"
  end

  # Given a debian platform and version, return the codename that corresponds to
  # the set
  def codename_for_platform_version(platform, version)
    get_attribute_for_platform_version(platform, version, :codename)
  end

  # Given a debian codename, return the arches that we build for that codename
  def arches_for_codename(codename)
    platform, version = codename_to_platform_version(codename)
    arches_for_platform_version(platform, version)
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
    get_attribute_for_platform_version(platform, version, :architectures)
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

  def package_format_for_tag(platform_tag)
    get_attribute(platform_tag, :package_format)
  end

  def signature_format_for_tag(platform_tag)
    get_attribute(platform_tag, :signature_format)
  end

  def signature_format_for_platform_version(platform, version)
    get_attribute_for_platform_version(platform, version, :signature_format)
  end

  def source_architecture_for_platform_tag(platform_tag)
    get_attribute(platform_tag, :source_architecture)
  end

  def source_package_formats_for_platform_tag(platform_tag)
    get_attribute(platform_tag, :source_package_formats)
  end

  # Return an array of platform tags associated with a given package format
  def platform_tags_for_package_format(format)
    platform_tags = []
    PLATFORM_INFO.each do |platform, platform_versions|
      platform_versions.each do |version, info|
        info[:architectures].each do |architecture|
          if info[:package_format] == format
            platform_tags << "#{platform}-#{version}-#{architecture}"
          end
        end
      end
    end
    platform_tags
  end

  # @method by_deb
  # @return [Array] An Array of Strings, containing all platforms
  #   that use .deb packages
  # Helper meta-method to return all platforms that use .deb packages
  # @scope class
  def by_deb
    by_package_format('deb')
  end

  # @method by_rpm
  # @return [Array] An Array of Strings, containing all platforms
  #   that use .rpm packages
  # Helper meta-method to return all platforms that use .rpm packages
  # @scope class
  def by_rpm
    by_package_format('rpm')
  end

  private :by_package_format
end
