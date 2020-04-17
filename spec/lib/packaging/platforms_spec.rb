require 'spec_helper'

describe 'Pkg::Platforms' do
  describe '#by_package_format' do
    it 'should return an array of platforms that use a given format' do
      deb_platforms = ['cumulus', 'debian', 'ubuntu']
      rpm_platforms = ['aix', 'cisco-wrlinux', 'el', 'fedora', 'redhatfips', 'sles']
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
      platforms = ['aix', 'cisco-wrlinux', 'cumulus', 'debian', 'el', 'eos', 'fedora', 'osx', 'redhatfips', 'sles', 'solaris', 'ubuntu', 'windows', 'windowsfips']
      expect(Pkg::Platforms.supported_platforms).to match_array(platforms)
    end
  end

  describe '#versions_for_platform' do
    it 'should return all supported versions for a given platform' do
      expect(Pkg::Platforms.versions_for_platform('el')).to match_array(['5', '6', '7', '8'])
    end

    it 'should raise an error if given a nonexistent platform' do
      expect{Pkg::Platforms.versions_for_platform('notaplatform') }.to raise_error
    end
  end

  describe '#codenames' do
    it 'should return all codenames for a given platform' do
      codenames = ['focal', 'bionic', 'buster', 'cosmic', 'cumulus', 'wheezy', 'jessie', 'stretch', 'trusty', 'xenial']
      expect(Pkg::Platforms.codenames).to match_array(codenames)
    end
  end

  describe '#codename_to_platform_version' do
    it 'should return the platform and version corresponding to a given codename' do
      expect(Pkg::Platforms.codename_to_platform_version('xenial')).to eq(['ubuntu', '16.04'])
    end

    it 'should fail if given nil as a codename' do
      expect{Pkg::Platforms.codename_to_platform_version(nil)}.to raise_error
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

    it 'should be able to include source archietectures' do
      expect(Pkg::Platforms.arches_for_codename('trusty', true)).to match_array(['i386', 'amd64', 'source'])
    end
  end

  describe '#codename_to_tags' do
    it 'should return an array of platform tags corresponding to a given codename' do
      expect(Pkg::Platforms.codename_to_tags('trusty')).to match_array(['ubuntu-14.04-i386', 'ubuntu-14.04-amd64'])
    end
  end

  describe '#arches_for_platform_version' do
    it 'should return an array of arches for a given platform and version' do
      expect(Pkg::Platforms.arches_for_platform_version('sles', '11')).to match_array(['i386', 'x86_64'])
    end

    it 'should be able to include source architectures' do
      expect(Pkg::Platforms.arches_for_platform_version('sles', '11', true)).to match_array(['i386', 'x86_64', 'SRPMS'])
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

  describe '#parse_platform_tag' do
    test_cases = {
      'debian-9-amd64' => ['debian', '9', 'amd64'],
      'windows-2012-x86' => ['windows', '2012', 'x86'],
      'windowsfips-2012-x64' => ['windowsfips', '2012', 'x64'],
      'el-7-x86_64' => ['el', '7', 'x86_64'],
      'cisco-wrlinux-7-x86_64' => ['cisco-wrlinux', '7', 'x86_64'],
      'cisco-wrlinux-7' => ['cisco-wrlinux', '7', ''],
      'el-6' => ['el', '6', ''],
      'xenial-amd64' => ['ubuntu', '16.04', 'amd64'],
      'xenial' => ['ubuntu', '16.04', ''],
      'windows-2012' => ['windows', '2012', ''],
      'redhatfips-7-x86_64' => ['redhatfips', '7', 'x86_64'],
      'el-7-SRPMS' => ['el', '7', 'SRPMS'],
      'ubuntu-14.04-source' => ['ubuntu', '14.04', 'source'],
    }

    fail_cases = [
      'debian-4-amd64',
      'el-x86_64',
      'nothing',
      'windows-x86',
      'el-7-notarch',
      'debian-7-x86_64',
      'el-7-source',
      'debian-7-SRPMS',
    ]

    test_cases.each do |platform_tag, results|
      it "returns an array for #{platform_tag}" do
        expect(Pkg::Platforms.parse_platform_tag(platform_tag)).to match_array(results)
      end
    end

    fail_cases.each do |platform_tag|
      it "fails out for #{platform_tag}" do
        expect { Pkg::Platforms.parse_platform_tag(platform_tag)}.to raise_error
      end
    end
  end

  describe '#generic_platform_tag' do
    it 'fails for unsupported platforms' do
      expect { Pkg::Platforms.generic_platform_tag('butts') }.to raise_error
    end

    it 'returns a supported platform tag containing the supplied platform' do
      Pkg::Platforms.supported_platforms.each do |platform|
        expect(Pkg::Platforms.platform_tags).to include(Pkg::Platforms.generic_platform_tag(platform))
      end
    end
  end
end
