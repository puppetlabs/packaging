require 'spec_helper'

describe 'Pkg::Paths' do
  describe '#tag_from_artifact_path' do
    path_tranformations = {
      'pkg/el-7-x86_64/puppet-agent-4.99.0-1.el7.x86_64.rpm' => 'el-7-x86_64',
      'pkg/ubuntu-16.04-amd64/puppet-agent_4.99.0-1xenial_amd64.deb' => 'ubuntu-16.04-amd64',
      'pkg/windows-x64/puppet-agent-4.99.0-x64.msi' => 'windows-2012-x64',
      'artifacts/el/6/products/x86_64/pe-r10k-2.5.4.3-1.el6.x86_64.rpm' => 'el-6-x86_64',
      'pkg/deb/trusty/pe-r10k_2.5.4.3-1trusty_amd64.deb' => 'ubuntu-14.04-amd64',
      'pkg/pe/rpm/el-6-i386/pe-puppetserver-2017.3.0.3-1.el6.noarch.rpm' => 'el-6-x86_64',
      'pkg/pe/deb/xenial/pe-puppetserver_2017.3.0.3-1puppet1_all.deb' => 'ubuntu-16.04-amd64',
      'artifacts/deb/wheezy/PC1/puppetdb_4.3.1-1puppetlabs1_all.deb' => 'debian-7-amd64',
      'pkg/el/7/PC1/x86_64/puppetdb-4.3.1-1.el7.noarch.rpm' => 'el-7-x86_64',
      'pkg/apple/10.11/PC1/x86_64/puppet-agent-1.9.0-1.osx10.11.dmg' => 'osx-10.11-x86_64',
      'artifacts/eos/4/PC1/i386/puppet-agent-1.9.0-1.eos4.i386.swix' => 'eos-4-i386',
      'pkg/windows/puppet-agent-1.9.0-x86.msi' => 'windows-2012-x86'
    }
    path_tranformations.each do |pre, post|
      it "should correctly parse path #{pre} to tag #{post}" do
        expect(Pkg::Paths.tag_from_artifact_path(pre)).to eq(post)
      end
    end

    failure_cases = [
      'pkg/pe/deb/preice',
      'pkg/el-4-x86_64'
    ]
    failure_cases.each do |fail_path|
      it 'should fail gracefully if it cannot figure out the correct platform tag' do
        expect { Pkg::Paths.tag_from_artifact_path(fail_path) }.to raise_error(RuntimeError, /#{fail_path.gsub('/', '\/')}/)
      end
    end
  end

  describe '#artifacts_path' do
    before :each do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet5')
    end

    it 'should be correct for el7' do
      expect(Pkg::Paths.artifacts_path('el-7-x86_64')).to eq('artifacts/puppet5/el/7/x86_64')
    end

    it 'should be correct for trusty' do
      expect(Pkg::Paths.artifacts_path('ubuntu-14.04-amd64')).to eq('artifacts/deb/trusty/puppet5')
    end

    it 'should be correct for solaris 11' do
      expect(Pkg::Paths.artifacts_path('solaris-11-sparc')).to eq('artifacts/solaris/puppet5/11')
    end

    it 'should be correct for osx' do
      expect(Pkg::Paths.artifacts_path('osx-10.10-x86_64')).to eq('artifacts/mac/puppet5/10.10/x86_64')
    end

    it 'should be correct for windows' do
      expect(Pkg::Paths.artifacts_path('windows-2012-x64')).to eq('artifacts/windows/puppet5')
    end

    it 'should work on all current platforms' do
      Pkg::Platforms.platform_tags.each do |tag|
        expect { Pkg::Paths.artifacts_path(tag) }.not_to raise_error
      end
    end
  end

  describe '#repo_path' do
    before :each do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet5')
    end

    it 'should be correct' do
      expect(Pkg::Paths.repo_path('el-7-x86_64')).to eq('repos/puppet5/el/7/x86_64')
    end

    it 'should work on all current platforms' do
      Pkg::Platforms.platform_tags.each do |tag|
        expect { Pkg::Paths.repo_path(tag) }.not_to raise_error
      end
    end
  end

  describe '#repo_config_path' do
    it 'should be correct' do
      expect(Pkg::Paths.repo_config_path('el-7-x86_64')).to eq('repo_configs/rpm/*el-7-x86_64*.repo')
    end

    it 'should work on all current platforms' do
      Pkg::Platforms.platform_tags.each do |tag|
        expect { Pkg::Paths.repo_config_path(tag) }.not_to raise_error
      end
    end
  end
end
