require 'set'

module Pkg
  module Platforms
    # Each element in this hash
    PLATFORM_INFO = {
      'aix' => {
        '5.3' => { :architectures => ['power'], :repo => false, :package_format => 'rpm', },
        '6.1' => { :architectures => ['power'], :repo => false, :package_format => 'rpm', },
        '7.1' => { :architectures => ['power'], :repo => false, :package_format => 'rpm', },
      },

      'cisco-wrlinux' => {
        '5' => { :architectures => ['x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
        '7' => { :architectures => ['x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
      },

      'cumulus' => {
        '2.2' => { :codename => 'cumulus', :architectures => ['amd64'], :repo => true, :package_format => 'deb', },
      },

      'debian' => {
        '6' => { :codename => 'squeeze', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
        '7' => { :codename => 'wheezy', :architectures  => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
        '8' => { :codename => 'jessie', :architectures  => ['i386', 'amd64', 'powerpc'], :repo => true, :package_format => 'deb', },
        '9' => { :codename => 'stretch', :architectures  => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
      },

      'el' => {
        '4' => { :architectures => ['i386', 'x86_64'], :repo => false, :package_format => 'rpm', :signature_format => 'v3', },
        '5' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v3', },
        '6' => { :architectures => ['i386', 'x86_64', 's390x'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
        '7' => { :architectures => ['x86_64', 's390x'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
      },

      'eos' => {
        '4' => { :architectures => ['i386'], :repo => false, :package_format => 'swix', },
      },

      'fedora' => {
        'f21' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
        'f22' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
        'f23' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
        'f24' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
      },

      'huaweios' => {
        '6' => { :codename => 'huaweios', :architectures => ['powerpc'], :repo => true, :package_format => 'deb', },
      },

      'osx' => {
        '10.9' => { :architectures => ['x86_64'], :repo => false, :package_format => 'dmg', },
        '10.10' => { :architectures => ['x86_64'], :repo => false, :package_format => 'dmg', },
        '10.11' => { :architectures => ['x86_64'], :repo => false, :package_format => 'dmg', },
        '10.12' => { :architectures => ['x86_64'], :repo => false, :package_format => 'dmg', },
      },

      'sles' => {
        '10' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v3', },
        '11' => { :architectures => ['i386', 'x86_64', 's390x'], :repo => true, :package_format => 'rpm', :signature_format => 'v3', },
        '12' => { :architectures => ['x86_64', 's390x'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
      },

      'solaris' => {
        '10' => { :architectures => ['i386', 'sparc'], :repo => false, :package_format => 'svr4', },
        '11' => { :architectures => ['i386', 'sparc'], :repo => false, :package_format => 'ips', },
      },

      'ubuntu' => {
        '10.04' => { :codename => 'lucid', :architectures   => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
        '12.04' => { :codename => 'precise', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
        '14.04' => { :codename => 'trusty', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
        '15.04' => { :codename => 'vivid', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
        '15.10' => { :codename => 'wily', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
        '16.04' => { :codename => 'xenial', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
      },

      'windows' => {
        '2012' => { :architectures => ['x86', 'x64'], :repo => false, :package_format => 'msi', },
      },
    }

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
