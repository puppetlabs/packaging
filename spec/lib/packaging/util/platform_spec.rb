require 'packaging/util/platform'

describe "Pkg::Util::Platform" do
  describe '#platform_tags' do
    it 'should return an array of platform tags' do
      tags = Pkg::Util::Platform.platform_tags
      expect(tags).to be_instance_of(Array)
      expect(tags.count).to be > 0
    end

    it 'should include a basic platform' do
      tags = Pkg::Util::Platform.platform_tags
      expect(tags).to include('el-7-x86_64')
    end
  end

  describe '#parse_platform_tag' do
    it 'fails with a reasonable error on invalid platform' do
      expect { Pkg::Util::Platform.parse_platform_tag("abcd-15-ia64") }.to raise_error(/valid platform tag/)
    end
  end

  describe '#repo_path' do
    it 'should be correct' do
      expect(Pkg::Util::Platform.repo_path('el-7-x86_64')).to eq('repos/el/7/**/x86_64')
    end

    it 'should work on all current platforms' do
      Pkg::Util::Platform.platform_tags.each do |tag|
        expect { Pkg::Util::Platform.repo_path(tag) }.not_to raise_error
      end
    end
  end

  describe '#artifacts_path' do
    it 'should be correct for el7' do
      expect(Pkg::Util::Platform.artifacts_path('el-7-x86_64')).to eq('artifacts/el/7')
    end

    it 'should be correct for trusty' do
      expect(Pkg::Util::Platform.artifacts_path('ubuntu-14.04-amd64')).to eq('artifacts/deb/trusty')
    end

    it 'should be correct for solaris 11' do
      expect(Pkg::Util::Platform.artifacts_path('solaris-11-sparc')).to eq('artifacts/solaris/11')
    end

    it 'should be correct for osx' do
      expect(Pkg::Util::Platform.artifacts_path('osx-10.10-x86_64')).to eq('artifacts/apple/10.10')
    end

    it 'should be correct for windows' do
      expect(Pkg::Util::Platform.artifacts_path('windows-2012-x64')).to eq('artifacts/windows')
    end

    it 'should work on all current platforms' do
      Pkg::Util::Platform.platform_tags.each do |tag|
        expect { Pkg::Util::Platform.artifacts_path(tag) }.not_to raise_error
      end
    end
  end


  describe '#repo_config_path' do
    it 'should be correct' do
      expect(Pkg::Util::Platform.repo_config_path('el-7-x86_64')).to eq('repo_configs/rpm/*el-7-x86_64*.repo')
    end

    it 'should work on all current platforms' do
      Pkg::Util::Platform.platform_tags.each do |tag|
        expect { Pkg::Util::Platform.repo_config_path(tag) }.not_to raise_error
      end
    end
  end
end
