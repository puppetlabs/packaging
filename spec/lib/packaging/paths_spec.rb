require 'spec_helper'

describe 'Pkg::Paths' do
  describe '#arch_from_artifact_path' do
    arch_transformations = {
      ['artifacts/aix/6.1/puppet6/ppc/puppet-agent-6.9.0-1.aix6.1.ppc.rpm', 'aix', '6.1'] => 'power',
      ['pkg/el-8-x86_64/puppet-agent-6.9.0-1.el8.x86_64.rpm', 'el', '8'] => 'x86_64',
      ['pkg/el/8/puppet6/aarch64/puppet-agent-6.5.0.3094.g16b6fa6f-1.el8.aarch64.rpm', 'el', '8'] => 'aarch64',
      ['artifacts/fedora/32/puppet6/x86_64/puppet-agent-6.9.0-1.fc30.x86_64.rpm', 'fedora', '32'] => 'x86_64',
      ['pkg/ubuntu-16.04-amd64/puppet-agent_4.99.0-1xenial_amd64.deb', 'ubuntu', '16.04'] => 'amd64',
      ['artifacts/deb/focal/puppet6/puppet-agent_6.5.0.3094.g16b6fa6f-1focal_arm64.deb', 'ubuntu', '20.04'] => 'aarch64',

      ['artifacts/ubuntu-16.04-i386/puppetserver_5.0.1-0.1SNAPSHOT.2017.07.27T2346puppetlabs1.debian.tar.gz', 'ubuntu', '16.04'] => 'source',
      ['artifacts/deb/jessie/PC1/puppetserver_5.0.1.master.orig.tar.gz', 'debian', '8'] => 'source',
      ['artifacts/el/6/PC1/SRPMS/puppetserver-5.0.1.master-0.1SNAPSHOT.2017.08.18T0951.el6.src.rpm', 'el', '6'] => 'SRPMS'
    }
    arch_transformations.each do |path_array, arch|
      it "should correctly return #{arch} for #{path_array[0]}" do
        expect(Pkg::Paths.arch_from_artifact_path(path_array[1], path_array[2], path_array[0]))
          .to eq(arch)
      end
    end
  end

  describe '#tag_from_artifact_path' do
    path_tranformations = {
      'artifacts/aix/6.1/puppet6/ppc/puppet-agent-6.9.0-1.aix6.1.ppc.rpm' => 'aix-6.1-power',
      'pkg/el-7-x86_64/puppet-agent-5.5.22-1.el8.x86_64.rpm' => 'el-7-x86_64',
      'pkg/ubuntu-20.04-amd64/puppet-agent_5.5.22-1xenial_amd64.deb' => 'ubuntu-20.04-amd64',
      'pkg/windows/puppet-agent-5.5.22-x86.msi' => 'windows-2012-x86',
      'artifacts/el/6/products/x86_64/pe-r10k-2.5.4.3-1.el6.x86_64.rpm' => 'el-6-x86_64',
      'pkg/pe/rpm/el-6-i386/pe-puppetserver-2017.3.0.3-1.el6.noarch.rpm' => 'el-6-i386',
      'pkg/deb/bionic/pe-r10k_3.5.2.0-1bionic_amd64.deb' => 'ubuntu-18.04-amd64',
      'pkg/deb/buster/pe-r10k_3.5.2.0-1buster_amd64.deb' => 'debian-10-amd64',
      'pkg/pe/deb/bionic/pe-puppetserver_2019.8.2.32-1bionic_all.deb' => 'ubuntu-18.04-amd64',
      'artifacts/deb/focal/puppet6/puppetdb_6.13.0-1focal_all.deb' => 'ubuntu-20.04-amd64',
      'pkg/apple/10.15/puppet6/x86_64/puppet-agent-6.19.0-1.osx10.15.dmg' => 'osx-10.15-x86_64',
      'pkg/windows/puppet-agent-1.9.0-x86.msi' => 'windows-2012-x86',
      'pkg/pe/rpm/el-6-i386/pe-puppetserver-2017.3.0.3-1.el6.src.rpm' => 'el-6-SRPMS',
      'pkg/pe/deb/xenial/pe-puppetserver_2017.3.0.3-1puppet1.orig.tar.gz' => 'ubuntu-16.04-source',
      'pkg/puppet-agent-5.1.0.79.g782e03c.gem' => nil,
      'pkg/puppet-agent-5.1.0.7.g782e03c.tar.gz' => nil,
    }
    path_tranformations.each do |pre, post|
      it "should correctly return '#{post}' when given #{pre}" do
        expect(Pkg::Paths.tag_from_artifact_path(pre)).to eq(post)
      end
    end

    failure_cases = [
      'pkg/pe/deb/preice',
      'pkg/el-4-x86_64',
      'a/package/that/sucks.rpm',
    ]
    failure_cases.each do |fail_path|
      it "should fail gracefully if given '#{fail_path}'" do
        expect { Pkg::Paths.tag_from_artifact_path(fail_path) }.to raise_error
      end
    end
  end

  describe '#repo_name' do
    it 'should return repo_name for final version' do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet6')
      expect(Pkg::Paths.repo_name).to eq('puppet6')
    end

    it 'should return repo_name for final version' do
      allow(Pkg::Config).to receive(:repo_name).and_return('FUTURE-puppet7')
      expect(Pkg::Paths.repo_name).to eq('FUTURE-puppet7')
    end

    it 'should be empty string if repo_name is not set for final version' do
      allow(Pkg::Config).to receive(:repo_name).and_return(nil)
      expect(Pkg::Paths.repo_name).to eq('')
    end

    it 'should return nonfinal_repo_name for non-final version' do
      allow(Pkg::Config).to receive(:nonfinal_repo_name).and_return('puppet6-nightly')
      expect(Pkg::Paths.repo_name(true)).to eq('puppet6-nightly')
    end

    it 'should fail if nonfinal_repo_name is not set for non-final version' do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet6')
      allow(Pkg::Config).to receive(:nonfinal_repo_name).and_return(nil)
      expect { Pkg::Paths.repo_name(true) }.to raise_error
    end
  end

  describe '#artifacts_path' do
    context 'all puppet versions' do
      before :each do
        allow(Pkg::Config).to receive(:repo_name).and_return('puppet6')
      end

      it 'should work on all current platforms' do
        Pkg::Platforms.platform_tags.each do |tag|
          expect { Pkg::Paths.artifacts_path(tag) }.not_to raise_error
        end
      end
    end

    context 'for puppet 6 and prior' do
      before :each do
        allow(Pkg::Config).to receive(:repo_name).and_return('puppet6')
      end

      it 'should be correct for el7' do
        expect(Pkg::Paths.artifacts_path('el-7-x86_64'))
          .to eq('artifacts/puppet6/el/7/x86_64')
      end

      it 'should be correct for bionic' do
        expect(Pkg::Paths.artifacts_path('ubuntu-18.04-amd64'))
          .to eq('artifacts/bionic/puppet6')
      end

      it 'should be correct for solaris 11' do
        expect(Pkg::Paths.artifacts_path('solaris-11-sparc'))
          .to eq('artifacts/solaris/puppet6/11')
      end

      it 'should be correct for osx' do
        expect(Pkg::Paths.artifacts_path('osx-10.15-x86_64'))
          .to eq('artifacts/mac/puppet6/10.15/x86_64')
      end

      it 'should be correct for windows' do
        expect(Pkg::Paths.artifacts_path('windows-2012-x64'))
          .to eq('artifacts/windows/puppet6')
      end
    end

    context 'after puppet 7 apt changes' do
      before :each do
        allow(Pkg::Config).to receive(:repo_name).and_return('FUTURE-puppet7')
      end

      it 'should be correct for bionic' do
        expect(Pkg::Paths.artifacts_path('ubuntu-18.04-amd64'))
          .to eq('artifacts/FUTURE-puppet7/bionic')
      end
      it 'should be correct for focal' do
        expect(Pkg::Paths.artifacts_path('ubuntu-20.04-amd64'))
          .to eq('artifacts/FUTURE-puppet7/focal')
      end
    end
  end

  describe '#repo_path' do
    before :each do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet6')
    end

    it 'should be correct' do
      expect(Pkg::Paths.repo_path('el-7-x86_64')).to eq('repos/puppet6/el/7/x86_64')
    end

    it 'should work on all current platforms' do
      Pkg::Platforms.platform_tags.each do |tag|
        expect { Pkg::Paths.repo_path(tag) }.not_to raise_error
      end
    end
  end

  describe '#repo_config_path' do
    it 'should construct rpm/deb-specific repo configs' do
      expect(Pkg::Paths.repo_config_path('el-7-x86_64'))
        .to eq('repo_configs/rpm/*el-7-x86_64*.repo')
      expect(Pkg::Paths.repo_config_path('ubuntu-18.04-amd64'))
        .to eq('repo_configs/deb/*bionic*.list')
    end

    it 'should raise a RuntimeError with unfamilar repo configs' do
      expect { Pkg::Paths.repo_config_path('bogus') }
        .to raise_error(/Could not verify that 'bogus' is a valid tag/)
    end

    it 'should work on all current platforms' do
      Pkg::Platforms.platform_tags.each do |tag|
        expect { Pkg::Paths.repo_config_path(tag) }.not_to raise_error
      end
    end
  end

  describe '#apt_repo_name' do
    it 'should return `Pkg::Config.repo_name` if set' do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet6')
      allow(Pkg::Config).to receive(:apt_repo_name).and_return('stuff')
      expect(Pkg::Paths.apt_repo_name).to eq('puppet6')
    end

    it 'should return `Pkg::Config.apt_repo_name` if `Pkg::Config.repo_name` is not set' do
      allow(Pkg::Config).to receive(:repo_name).and_return(nil)
      allow(Pkg::Config).to receive(:apt_repo_name).and_return('puppet6')
      expect(Pkg::Paths.apt_repo_name).to eq('puppet6')
    end

    it 'should return \'main\' if nothing is set' do
      allow(Pkg::Config).to receive(:repo_name).and_return(nil)
      allow(Pkg::Config).to receive(:apt_repo_name).and_return(nil)
      expect(Pkg::Paths.apt_repo_name).to eq('main')
    end

    it 'should return nonfinal_repo_name for nonfinal version' do
      allow(Pkg::Config).to receive(:repo_name).and_return('FUTURE-puppet7')
      allow(Pkg::Config).to receive(:nonfinal_repo_name).and_return('FUTURE-puppet7-nightly')
      expect(Pkg::Paths.apt_repo_name(true)).to eq('FUTURE-puppet7-nightly')
    end

    it 'should fail if nonfinal_repo_name is not set for non-final version' do
      allow(Pkg::Config).to receive(:repo_name).and_return('FUTURE-puppet7')
      allow(Pkg::Config).to receive(:nonfinal_repo_name).and_return(nil)
      expect { Pkg::Paths.apt_repo_name(true) }.to raise_error
    end
  end

  describe '#yum_repo_name' do
    it 'should return `Pkg::Config.repo_name` if set' do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet6')
      allow(Pkg::Config).to receive(:yum_repo_name).and_return('stuff')
      expect(Pkg::Paths.yum_repo_name).to eq('puppet6')
    end

    it 'should return `Pkg::Config.yum_repo_name` if `Pkg::Config.repo_name` is not set' do
      allow(Pkg::Config).to receive(:repo_name).and_return(nil)
      allow(Pkg::Config).to receive(:yum_repo_name).and_return('FUTURE-puppet7')
      expect(Pkg::Paths.yum_repo_name).to eq('FUTURE-puppet7')
    end

    it 'should return \'products\' if nothing is set' do
      allow(Pkg::Config).to receive(:repo_name).and_return(nil)
      allow(Pkg::Config).to receive(:yum_repo_name).and_return(nil)
      expect(Pkg::Paths.yum_repo_name).to eq('products')
    end

    it 'should return nonfinal_repo_name for nonfinal version' do
      allow(Pkg::Config).to receive(:repo_name).and_return('FUTURE-puppet7')
      allow(Pkg::Config).to receive(:nonfinal_repo_name).and_return('FUTURE-puppet7-nightly')
      expect(Pkg::Paths.yum_repo_name(true)).to eq('FUTURE-puppet7-nightly')
    end

    it 'should fail if nonfinal_repo_name is not set for non-final version' do
      allow(Pkg::Config).to receive(:repo_name).and_return('FUTURE-puppet7')
      allow(Pkg::Config).to receive(:nonfinal_repo_name).and_return(nil)
      expect { Pkg::Paths.yum_repo_name(true) }.to raise_error
    end
  end

  describe '#remote_repo_base' do
    fake_yum_repo_path = '/fake/yum'
    fake_yum_nightly_repo_path = '/fake/yum-nightly'
    fake_apt_repo_path = '/fake/apt'
    fake_apt_nightly_repo_path = '/fake/apt-nightly'

    before :each do
      allow(Pkg::Config).to receive(:yum_repo_path).and_return(fake_yum_repo_path)
      allow(Pkg::Config).to receive(:apt_repo_path).and_return(fake_apt_repo_path)
      allow(Pkg::Config).to receive(:dmg_path).and_return('/opt/downloads/mac')
      allow(Pkg::Config).to receive(:nonfinal_yum_repo_path).and_return(fake_yum_nightly_repo_path)
      allow(Pkg::Config).to receive(:nonfinal_apt_repo_path).and_return(fake_apt_nightly_repo_path)
    end
    it 'returns yum_repo_path for rpms' do
      expect(Pkg::Paths.remote_repo_base('el-7-x86_64'))
        .to eq(fake_yum_repo_path)
    end
    it 'returns apt_repo_path for debs' do
      expect(Pkg::Paths.remote_repo_base('ubuntu-18.04-amd64'))
        .to eq(fake_apt_repo_path)
    end
    it 'returns nonfinal_yum_repo_path for nonfinal rpms' do
      expect(Pkg::Paths.remote_repo_base('fedora-31-x86_64', nonfinal: true))
        .to eq(fake_yum_nightly_repo_path)
    end
    it 'returns nonfinal_apt_repo_path for nonfinal debs' do
      expect(Pkg::Paths.remote_repo_base('debian-9-amd64', nonfinal: true))
        .to eq(fake_apt_nightly_repo_path)
    end
    it 'fails if neither tag nor package_format is provided' do
      expect { Pkg::Paths.remote_repo_base }
        .to raise_error(/Pkg::Paths.remote_repo_base must have/)
    end

    it 'returns /opt/downloads if the path is /opt/downloads/<something>' do
      expect(Pkg::Paths.remote_repo_base(package_format: 'dmg')).to eq('/opt/downloads')
    end

    it 'fails for all other package formats' do
      expect { Pkg::Paths.remote_repo_base('solaris-11-i386') }
        .to raise_error(/Can't determine remote repo base path/)
    end
  end

  describe '#apt_package_base_path' do
    it 'fails for non-debian platforms' do
      expect { Pkg::Paths.apt_package_base_path('el-7-x86_64', 'puppet6', 'puppet-agent') }
        .to raise_error(/Can't determine path for non-debian platform/)
    end

    context 'for puppet 6 and prior' do
      it 'returns the approprate apt repo path' do
        allow(Pkg::Paths).to receive(:remote_repo_base).and_return('/opt/repository/apt')
        expect(Pkg::Paths.apt_package_base_path('ubuntu-18.04-amd64', 'puppet6', 'puppet-agent'))
          .to eq('/opt/repository/apt/pool/bionic/puppet6/p/puppet-agent')
        expect(Pkg::Paths.apt_package_base_path('debian-9-amd64', 'puppet6', 'bolt-server'))
          .to eq('/opt/repository/apt/pool/stretch/puppet6/b/bolt-server')


      end
      it 'returns the appropriate nonfinal repo path' do
        allow(Pkg::Paths).to receive(:remote_repo_base).and_return('/opt/repository-nightlies/apt')
        expect(Pkg::Paths.apt_package_base_path('ubuntu-18.04-amd64', 'puppet6-nightly',
                                                'puppet-agent', true))
          .to eq('/opt/repository-nightlies/apt/pool/bionic/puppet6-nightly/p/puppet-agent')
        expect(Pkg::Paths.apt_package_base_path('debian-10-amd64', 'puppet6-nightly',
                                                'pdk', true))
          .to eq('/opt/repository-nightlies/apt/pool/buster/puppet6-nightly/p/pdk')
      end
    end

    context 'for puppet 7 and after' do
      it 'returns the approprate apt repo path' do
        allow(Pkg::Paths).to receive(:remote_repo_base).and_return('/opt/repository/apt')
        expect(Pkg::Paths.apt_package_base_path('ubuntu-18.04-amd64', 'FUTURE-puppet7', 'puppet-agent'))
          .to eq('/opt/repository/apt/FUTURE-puppet7/pool/bionic/p/puppet-agent')
        expect(Pkg::Paths.apt_package_base_path('ubuntu-20.04-amd64', 'FUTURE-puppet7', 'puppet-agent'))
          .to eq('/opt/repository/apt/FUTURE-puppet7/pool/focal/p/puppet-agent')
      end
      it 'returns the appropriate nonfinal repo path' do
        allow(Pkg::Paths).to receive(:remote_repo_base).and_return('/opt/repository-nightlies/apt')
        expect(Pkg::Paths.apt_package_base_path('debian-10-amd64', 'FUTURE-puppet7-nightly', 'pdk', true))
          .to eq('/opt/repository-nightlies/apt/FUTURE-puppet7-nightly/pool/buster/p/pdk')
      end
    end
  end

  describe '#release_package_link_path' do
    context 'for puppet 6' do
      repo_name = 'puppet6'
      nonfinal_repo_name = 'puppet6-nightly'
      yum_repo_path = '/opt/repository/yum'
      apt_repo_path = '/opt/repository/apt'
      nonfinal_yum_repo_path = '/opt/repository-nightlies/yum'
      nonfinal_apt_repo_path = '/opt/repository-nightlies/apt'
      before :each do
        allow(Pkg::Config).to receive(:repo_name).and_return(repo_name)
        allow(Pkg::Config).to receive(:nonfinal_repo_name).and_return(nonfinal_repo_name)
        allow(Pkg::Config).to receive(:yum_repo_path).and_return(yum_repo_path)
        allow(Pkg::Config).to receive(:apt_repo_path).and_return(apt_repo_path)
        allow(Pkg::Config).to receive(:nonfinal_yum_repo_path).and_return(nonfinal_yum_repo_path)
        allow(Pkg::Config).to receive(:nonfinal_apt_repo_path).and_return(nonfinal_apt_repo_path)
      end
      it 'returns the appropriate link path for rpm release packages' do
        expect(Pkg::Paths.release_package_link_path('sles-12-ppc64le'))
          .to eq("#{yum_repo_path}/#{repo_name}-release-sles-12.noarch.rpm")
      end
      it 'returns the appropriate link path for deb release packages' do
        expect(Pkg::Paths.release_package_link_path('ubuntu-16.04-amd64'))
          .to eq("#{apt_repo_path}/#{repo_name}-release-xenial.deb")
      end
      it 'returns the appropriate link path for nonfinal rpm release packages' do
        expect(Pkg::Paths.release_package_link_path('el-7-x86_64', true))
          .to eq("#{nonfinal_yum_repo_path}/#{nonfinal_repo_name}-release-el-7.noarch.rpm")
      end
      it 'returns the appropriate link path for nonfinal deb release packages' do
        expect(Pkg::Paths.release_package_link_path('debian-9-i386', true))
          .to eq("#{nonfinal_apt_repo_path}/#{nonfinal_repo_name}-release-stretch.deb")
      end
      it 'returns nil for package formats that do not have release packages' do
        expect(Pkg::Paths.release_package_link_path('osx-10.15-x86_64')).to eq(nil)
        expect(Pkg::Paths.release_package_link_path('windows-2012-x86')).to eq(nil)
      end
    end

    context 'for puppet 7' do
      repo_name = 'FUTURE-puppet7'
      nonfinal_repo_name = 'FUTURE-puppet7-nightly'
      yum_repo_path = '/opt/repository/yum'
      apt_repo_path = '/opt/repository/apt'
      nonfinal_yum_repo_path = '/opt/repository-nightlies/yum'
      nonfinal_apt_repo_path = '/opt/repository-nightlies/apt'
      before :each do
        allow(Pkg::Config).to receive(:repo_name).and_return(repo_name)
        allow(Pkg::Config).to receive(:nonfinal_repo_name).and_return(nonfinal_repo_name)
        allow(Pkg::Config).to receive(:yum_repo_path).and_return(yum_repo_path)
        allow(Pkg::Config).to receive(:apt_repo_path).and_return(apt_repo_path)
        allow(Pkg::Config).to receive(:nonfinal_yum_repo_path).and_return(nonfinal_yum_repo_path)
        allow(Pkg::Config).to receive(:nonfinal_apt_repo_path).and_return(nonfinal_apt_repo_path)
      end
      it 'returns the appropriate link path for rpm release packages' do
        expect(Pkg::Paths.release_package_link_path('sles-12-ppc64le'))
          .to eq("#{yum_repo_path}/#{repo_name}-release-sles-12.noarch.rpm")
      end
      it 'returns the appropriate link path for deb release packages' do
        expect(Pkg::Paths.release_package_link_path('ubuntu-20.04-amd64'))
          .to eq("#{apt_repo_path}/#{repo_name}-release-focal.deb")
      end
      it 'returns the appropriate link path for nonfinal rpm release packages' do
        expect(Pkg::Paths.release_package_link_path('el-8-x86_64', true))
          .to eq("#{nonfinal_yum_repo_path}/#{nonfinal_repo_name}-release-el-8.noarch.rpm")
      end
      it 'returns the appropriate link path for nonfinal deb release packages' do
        expect(Pkg::Paths.release_package_link_path('debian-10-i386', true))
          .to eq("#{nonfinal_apt_repo_path}/#{nonfinal_repo_name}-release-buster.deb")
      end
      it 'returns nil for package formats that do not have release packages' do
        expect(Pkg::Paths.release_package_link_path('osx-10.15-x86_64')).to eq(nil)
        expect(Pkg::Paths.release_package_link_path('windows-2012-x86')).to eq(nil)
      end
    end
  end
end
