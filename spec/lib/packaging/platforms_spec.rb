require 'spec_helper'

describe 'Pkg::Platforms' do
  describe '#by_package_format' do
    it 'should return an array of platforms that use a given format' do
      deb_platforms = ['debian', 'ubuntu']
      rpm_platforms = ['aix', 'el', 'fedora', 'redhatfips', 'sles']
      expect(Pkg::Platforms.by_package_format('deb')).to match_array(deb_platforms)
      expect(Pkg::Platforms.by_package_format('rpm')).to match_array(rpm_platforms)
    end
  end

  describe '#formats' do
    it 'should return all package formats' do
      fmts = ['rpm', 'deb', 'dmg', 'svr4', 'ips', 'msi']
      expect(Pkg::Platforms.formats).to match_array(fmts)
    end
  end

  describe '#supported_platforms' do
    it 'should return all supported platforms' do
      platforms = ['aix', 'debian', 'el', 'fedora', 'osx', 'redhatfips', 'sles', 'solaris', 'ubuntu', 'windows', 'windowsfips']
      expect(Pkg::Platforms.supported_platforms).to match_array(platforms)
    end
  end

  describe '#versions_for_platform' do
    it 'should return all supported versions for a given platform' do
      expect(Pkg::Platforms.versions_for_platform('el')).to match_array(['6', '7', '8', '9'])
    end

    it 'should raise an error if given a nonexistent platform' do
      expect{Pkg::Platforms.versions_for_platform('notaplatform') }.to raise_error
    end
  end

  describe '#codenames' do
    it 'should return all codenames for a given platform' do
      codenames = ['focal', 'bionic', 'bullseye', 'buster', 'stretch', 'trusty', 'xenial', 'jammy']
      expect(Pkg::Platforms.codenames).to match_array(codenames)
    end
  end

  describe '#codename_to_platform_version' do
    it 'should return the platform and version corresponding to a given codename' do
      expect(Pkg::Platforms.codename_to_platform_version('xenial')).to eq(['ubuntu', '16.04'])
    end

    it 'should return the platform and version corresponding to a given codename' do
      expect(Pkg::Platforms.codename_to_platform_version('jammy')).to eq(['ubuntu', '22.04'])
    end

    it 'should fail if given nil as a codename' do
      expect{Pkg::Platforms.codename_to_platform_version(nil)}.to raise_error
    end
  end

  describe '#codename_for_platform_version' do
    it 'should return the codename corresponding to a given platform and version' do
      expect(Pkg::Platforms.codename_for_platform_version('ubuntu', '22.04')).to eq('jammy')
    end
  end

  describe '#arches_for_codename' do
    it 'should return an array of arches corresponding to a given codename' do
      expect(Pkg::Platforms.arches_for_codename('xenial')).to match_array(['amd64', 'i386', 'ppc64el'])
    end

    it 'should be able to include source archietectures' do
      expect(Pkg::Platforms.arches_for_codename('xenial', true)).to match_array(["amd64", "i386", "ppc64el", "source"])
    end
  end

  describe '#codename_to_tags' do
    it 'should return an array of platform tags corresponding to a given codename' do
      expect(Pkg::Platforms.codename_to_tags('xenial')).to match_array(['ubuntu-16.04-i386', 'ubuntu-16.04-amd64', "ubuntu-16.04-ppc64el"])
    end
  end

  describe '#arches_for_platform_version' do
    it 'should return an array of arches for a given platform and version' do
      expect(Pkg::Platforms.arches_for_platform_version('sles', '12')).to match_array(['x86_64', 'ppc64le'])
    end

    it 'should be able to include source architectures' do
      expect(Pkg::Platforms.arches_for_platform_version('sles', '12', true)).to match_array(["SRPMS", "ppc64le", "x86_64"])
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
    ['osx-10.15-x86_64', 'osx-11-x86_64', 'osx-12-x86_64'].each do |platform|
      it 'should return a hash of platform info' do
        expect(Pkg::Platforms.platform_lookup(platform)).to be_instance_of(Hash)
      end

      it 'should include at least arch and package format keys' do
        expect(Pkg::Platforms.platform_lookup(platform).keys).to include(:architectures)
        expect(Pkg::Platforms.platform_lookup(platform).keys).to include(:package_format)
      end
    end
  end

  describe '#get_attribute' do
    it 'returns info about a given platform' do
      expect(Pkg::Platforms.get_attribute('el-6-x86_64', :signature_format)).to eq('v4')
    end

    it 'fails with a reasonable error when specified attribute is not defined' do
      expect { Pkg::Platforms.get_attribute('osx-10.15-x86_64', :signature_format) }.to raise_error(/doesn't have information/)
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
      'el-6' => ['el', '6', ''],
      'xenial-amd64' => ['ubuntu', '16.04', 'amd64'],
      'xenial' => ['ubuntu', '16.04', ''],
      'windows-2012' => ['windows', '2012', ''],
      'redhatfips-7-x86_64' => ['redhatfips', '7', 'x86_64'],
      'el-7-SRPMS' => ['el', '7', 'SRPMS'],
      'ubuntu-16.04-source' => ['ubuntu', '16.04', 'source'],
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
      expect { Pkg::Platforms.generic_platform_tag('noplatform') }.to raise_error
    end

    it 'returns a supported platform tag containing the supplied platform' do
      Pkg::Platforms.supported_platforms.each do |platform|
        expect(Pkg::Platforms.platform_tags).to include(Pkg::Platforms.generic_platform_tag(platform))
      end
    end
  end
end
