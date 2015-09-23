module Pkg::Platforms
  # Each element in this hash
  PLATFORM_INFO = {
    'el' => {
      '4' => { :architectures => ['i386', 'x86_64'], :repo => false, :package_format => 'rpm', :signature_format => 'v3', },
      '5' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v3', },
      '6' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
      '7' => { :architectures => ['x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
    },

    'sles' => {
      '10' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v3', },
      '11' => { :architectures => ['i386', 'x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v3', },
      '12' => { :architectures => ['x86_64'], :repo => true, :package_format => 'rpm', :signature_format => 'v4', },
    },

    'debian' => {
      '6' => { :codename => 'squeeze', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
      '7' => { :codename => 'wheezy', :architectures  => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
      '8' => { :codename => 'jessie', :architectures  => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
      '9' => { :codename => 'stretch', :architectures  => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
    },

    'ubuntu' => {
      '10.04' => { :codename => 'lucid', :architectures   => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
      '12.04' => { :codename => 'precise', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
      '14.04' => { :codename => 'trusty', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
      '15.04' => { :codename => 'vivid', :architectures => ['i386', 'amd64'], :repo => true, :package_format => 'deb', },
    },

    'cumulus' => {
      '2.2' => { :codename => 'cumulus', :architectures => ['amd64'], :repo => true, :package_format => 'deb', },
    },

    'aix' => {
      '5.3' => { :architectures => ['power'], :repo => false, :package_format => 'rpm', },
      '6.1' => { :architectures => ['power'], :repo => false, :package_format => 'rpm', },
      '7.1' => { :architectures => ['power'], :repo => false, :package_format => 'rpm', },
    },

    'solaris' => {
      '10' => { :architectures => ['i386', 'sparc'], :repo => false, :package_format => 'srv4', },
      '11' => { :architectures => ['i386', 'sparc'], :repo => false, :package_format => 'ips', },
    },

    'eos' => {
      '4' => { :architectures => ['i386'], :repo => false, :package_format => 'swix', },
    },

    'osx' => {
      '10.9' => { :architectures => ['x86_64'], :repo => false, :package_format => 'dmg', },
      '10.10' => { :architectures => ['x86_64'], :repo => false, :package_format => 'dmg', },
    },

    'windows' => {
      '2012' => { :architectures => ['x86', 'x64'], :repo => false, :package_format => 'msi', },
    },
  }
end
