require 'spec_helper'
require 'packaging/retrieve'
require 'packaging/paths'

describe 'Pkg::Retrieve' do
  local_target = 'pkg'
  remote_target = 'repos'
  project = 'puppet-agent'
  ref = 'b25e64984dd505391f248fe5501ad81e2645b6d2'
  foss_platforms = ['el-7-x86_64', 'ubuntu-16.04-amd64', 'osx-10.11-x86_64', 'windows-2012-x64']
  platform_data = {:platform_data => {
    'aix-7.1-power' => {:artifact => './aix/7.1/PC1/ppc/puppet-agent-5.3.2.155.gb25e649-1.aix7.1.ppc.rpm'},
    'el-7-x86_64' => {:artifact => './el/7/PC1/x86_64/puppet-agent-5.3.2.155.gb25e649-1.el7.x86_64.rpm'},
    'osx-10.11-x86_64' => {:artifact => './apple/10.11/PC1/x86_64/puppet-agent-5.3.2.155.gb25e649-1.osx10.11.dmg'},
    'sles-11-i386' => {:artifact => './sles/11/PC1/i386/puppet-agent-5.3.2.155.gb25e649-1.sles11.i386.rpm'},
    'solaris-10-sparc' => {:artifact => './solaris/10/PC1/puppet-agent-5.3.2.155.gb25e649-1.sparc.pkg.gz'},
    'ubuntu-16.04-amd64' => {:artifact => './deb/xenial/PC1/puppet-agent_5.3.2.155.gb25e649-1xenial_amd64.deb'},
    'windows-2012-x64' => {:artifact => './windows/puppet-agent-x64.msi'},
  }}
  build_url = "builds.delivery.puppetlabs.net/#{project}/#{ref}/#{remote_target}"
  build_path = "/opt/jenkins-builds/#{project}/#{ref}/#{remote_target}"

  before :each do
    allow(Pkg::Config).to receive(:project).and_return(project)
    allow(Pkg::Config).to receive(:ref).and_return(ref)
    allow(Pkg::Config).to receive(:foss_platforms).and_return(foss_platforms)
    allow(File).to receive(:readable?).with("#{local_target}/#{ref}.yaml").and_return(true)
    allow(Pkg::Util::Serialization).to receive(:load_yaml).and_return(platform_data)
  end

  describe '#default_wget_command' do
    let(:options) { [
      "--quiet",
      "--recursive",
      "--no-parent",
      "--no-host-directories",
      "--level=0",
      "--cut-dirs=3",
      "--directory-prefix=#{local_target}",
      "--reject='index*",
    ] }
    before :each do
      allow(Pkg::Util::Tool).to receive(:check_tool).with('wget').and_return('wget')
    end
    context 'when no options passed' do
      it 'should include default options' do
        options.each do |option|
          expect(Pkg::Retrieve.default_wget_command(local_target, build_url)).to include(option)
        end
      end
    end
    context 'when options are passed' do
      it 'should add to existing options' do
        options.push('--convert-links')
        options.each do |option|
          expect(Pkg::Retrieve.default_wget_command(local_target, build_url, {'convert-links' => true})).to include(option)
        end
      end
      it 'should replace default values' do
        options.push('--level=1').delete('--level=0')
        expect(Pkg::Retrieve.default_wget_command(local_target, build_url, {'level' => 1})).to_not include('--level=0')
        options.each do |option|
          expect(Pkg::Retrieve.default_wget_command(local_target, build_url, {'level' => 1})).to include(option)
        end
      end
    end
  end

  describe '#foss_only_retrieve' do
    it 'should fail without foss_platforms' do
      allow(Pkg::Config).to receive(:foss_platforms).and_return(nil)
      expect { Pkg::Retrieve.foss_only_retrieve(build_url, local_target) }.to raise_error(/I don't know anything about FOSS_PLATFORMS/)
    end

    it 'should fail if cannot read <ref>.yaml' do
      allow(File).to receive(:readable?).with("#{local_target}/#{ref}.yaml").and_return(false)
      expect { Pkg::Retrieve.foss_only_retrieve(build_url, local_target) }.to raise_error(/Couldn't read #{ref}.yaml/)
    end

    it 'should retrieve foss_only packages' do
      expect(Pkg::Retrieve).to receive(:default_wget).exactly(1 + foss_platforms.count).times
      Pkg::Retrieve.foss_only_retrieve(build_url, local_target)
    end
  end

  describe '#retrieve_all' do
    it 'should try to use wget first' do
      expect(Pkg::Retrieve).to receive(:default_wget)
      Pkg::Retrieve.retrieve_all(build_url, build_path, local_target)
    end

    it 'should use rsync if wget is not found' do
      allow(Pkg::Util::Tool).to receive(:find_tool).with('wget').and_return(nil)
      expect(Pkg::Util::Net).to receive(:rsync_from)
      Pkg::Retrieve.retrieve_all(build_url, build_path, local_target)
    end
  end
end

