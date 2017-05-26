require 'spec_helper'

describe 'Pkg::Platforms' do
  describe '#by_package_format' do
    it 'should return an array of platforms that use a given format' do
      deb_platforms = ['cumulus', 'debian', 'huaweios', 'ubuntu']
      rpm_platforms = ['aix', 'cisco-wrlinux', 'el', 'fedora', 'sles']
      expect(Pkg::Platforms.by_package_format('deb')).to match_array(deb_platforms)
      expect(Pkg::Platforms.by_package_format('rpm')).to match_array(rpm_platforms)
    end
  end

  describe '#formats' do
    it 'should return all package formats' do
      fmts = ['rpm', 'deb', 'swix', 'dmg', 'svr4', 'ips', 'msi']
      expect(Pkg::Platforms.formats).to match_array(fmts)
    end
  end

  describe '#supported_platforms' do
    it 'should return all supported platforms' do
      platforms = ['aix', 'cisco-wrlinux', 'cumulus', 'debian', 'el', 'eos', 'fedora', 'huaweios', 'osx', 'sles', 'solaris', 'ubuntu', 'windows']
      expect(Pkg::Platforms.supported_platforms).to match_array(platforms)
    end
  end

  describe '#versions_for_platform' do
    it 'should return all supported versions for a given platform' do
      expect(Pkg::Platforms.versions_for_platform('el')).to match_array(['5', '6', '7'])
    end
  end

  describe '#codenames' do
    it 'should return all codenames for a given platform' do
      codenames = ['cumulus', 'wheezy', 'jessie', 'stretch', 'huaweios', 'trusty', 'xenial', 'yakkety']
      expect(Pkg::Platforms.codenames('deb')).to match_array(codenames)
    end
  end

  describe '#codename_to_platform_version' do
    it 'should return the platform and version corresponding to a given codename' do
      expect(Pkg::Platforms.codename_to_platform_version('xenial')).to eq(['ubuntu', '16.04'])
    end
  end

  describe '#codename_for_platform_version' do
    it 'should return the codename corresponding to a given platform and version' do
      expect(Pkg::Platforms.codename_for_platform_version('ubuntu', '16.04')).to eq('xenial')
    end
  end

  describe '#arches_for_codename' do
    it 'should return an array of arches corresponding to a given codename' do
      expect(Pkg::Platforms.arches_for_codename('trusty')).to match_array(['i386', 'amd64'])
    end
  end

  describe '#codename_to_tags' do
    it 'should return an array of platform tags corresponding to a given codename' do
      expect(Pkg::Platforms.codename_to_tags('trusty')).to match_array(['ubuntu-14.04-i386', 'ubuntu-14.04-amd64'])
    end
  end

  describe '#arches_for_platform_version' do
    it 'should return an array of arches for a given platform and version' do
      expect(Pkg::Platforms.arches_for_platform_version('sles', '11')).to match_array(['i386', 'x86_64', 's390x'])
    end
  end

  describe '#platform_tags' do
    it 'should return an array of platform tags' do
      tags = Pkg::Platforms.platform_tags
      expect(tags).to be_instance_of(Array)
      expect(tags.count).to be > 0
    end

    it 'should include a basic platform' do
      tags = Pkg::Platforms.platform_tags
      expect(tags).to include('el-7-x86_64')
    end
  end

  describe '#platform_lookup' do
    it 'should return a hash of platform info' do
      expect(Pkg::Platforms.platform_lookup('osx-10.10-x86_64')).to be_instance_of(Hash)
    end

    it 'should include at least arch and package format keys' do
      expect(Pkg::Platforms.platform_lookup('osx-10.10-x86_64').keys).to include(:architectures)
      expect(Pkg::Platforms.platform_lookup('osx-10.10-x86_64').keys).to include(:package_format)
    end
  end

  describe '#parse_platform_tag' do
    it 'fails with a reasonable error on invalid platform' do
      expect { Pkg::Platforms.parse_platform_tag('abcd-15-ia64') }.to raise_error(/valid platform tag/)
    end
  end

  describe '#get_attribute' do
    it 'returns info about a given platform' do
      expect(Pkg::Platforms.get_attribute('el-6-x86_64', :signature_format)).to eq('v4')
    end

    it 'fails with a reasonable error when specified attribute is not defined' do
      expect { Pkg::Platforms.get_attribute('eos-4-i386', :signature_format) }.to raise_error(/doesn't have information/)
    end
  end

  describe '#package_format_for_tag' do
    it 'should return the package format for a given platform tag' do
      expect(Pkg::Platforms.package_format_for_tag('windows-2012-x86')).to eq('msi')
    end
  end
end
