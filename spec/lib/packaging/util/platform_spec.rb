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
  end

  describe '#repo_config_path' do
    it 'should be correct' do
      expect(Pkg::Util::Platform.repo_config_path('el-7-x86_64')).to eq('repo_configs/rpm/*el-7-x86_64*.repo')
    end
  end
end
