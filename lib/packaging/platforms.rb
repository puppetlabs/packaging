require 'set'

module Pkg
  module Platforms
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
        },
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
        },
      },

      'cumulus' => {
        '2.2' => {
          codename: 'cumulus',
          architectures: ['amd64'],
          source_architecture: 'source',
          package_format: 'deb',
          source_package_formats: DEBIAN_SOURCE_FORMATS,
          repo: true,
        },
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
        },
        '10' => {
          codename: 'buster',
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
        },
      },

      'eos' => {
        '4' => {
          architectures: ['i386'],
          package_format: 'swix',
          repo: false,
        },
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
        'f27' => {
          architectures: ['x86_64'],
          source_architecture: 'SRPMS',
          package_format: 'rpm',
          source_package_formats: ['src.rpm'],
          signature_format: 'v4',
          repo: true,
        },
        'f28' => {
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
        '27' => {
          architectures: ['x86_64'],
          source_architecture: 'SRPMS',
          package_format: 'rpm',
          source_package_formats: ['src.rpm'],
          signature_format: 'v4',
          repo: true,
        },
        '28' => {
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
        },
        '10.13' => {
          architectures: ['x86_64'],
          package_format: 'dmg',
          repo: false,
        },
      },

      'redhatfips' => {
        '7' => {
          architectures: ['x86_64'],
          source_architecture: 'SRPMS',
          package_format: 'rpm',
          source_package_formats: ['src.rpm'],
          signature_format: 'v3',
          repo: true,
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
        },
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
        },
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
        '18.04' => {
          codename: 'bionic',
          architectures: ['amd64', 'ppc64el'],
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
        },
      }
    }.freeze

    # @private List platforms that use a given package format
    # @param format [String] The name of the packaging format to filter on
    # @return [Array] An Array of Strings, containing all platforms that
    #   use <format> for their packages
    def by_package_format(format)
      Pkg::Platforms::PLATFORM_INFO.keys.select do |key|
        formats = Pkg::Platforms::PLATFORM_INFO[key].values.collect { |v| v[:package_format] }
        formats.include? format
      end
    end
    module_function :by_package_format

    # @return [Array] An Array of Strings, containing all of the package
    #   formats defined in Pkg::Platforms
    def formats
      fmts = Pkg::Platforms::PLATFORM_INFO.flat_map do |_, p|
        p.collect do |_, r|
          r[:package_format]
        end
      end
      fmts.to_set.sort
    end
    module_function :formats

    # @param platform [String] The platform to list all codenames for
    # @return [Array] An Array of Strings, containing all of the codenames
    #   defined for a given Platform
    def codenames(platform)
      releases = self.send("by_#{platform}".to_s).flat_map do |p|
        Pkg::Platforms::PLATFORM_INFO[p].values.collect { |r| r[:codename] }
      end
      releases.sort
    end
    module_function :codenames

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
      module_function type
    end

    # Make #by_package_format private
    class << self
      private :by_package_format
    end
  end
end
