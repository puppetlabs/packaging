require 'spec_helper'

describe '#Pkg::Util::Ship' do
  describe '#collect_packages' do
    msi_pkgs = [
      'pkg/windows/puppet5/puppet-agent-1.4.1.2904.g8023dd1-x86.msi',
      'pkg/windows/puppet5/puppet-agent-x86.msi',
      'pkg/windowsfips/puppet5/puppet-agent-1.4.1.2904.g8023dd1-x64.msi',
      'pkg/windowsfips/puppet5/puppet-agent-x64.msi'
    ]

    describe 'define excludes' do
      before :each do
        allow(Dir).to receive(:glob).with('pkg/**/*.msi').and_return(msi_pkgs)
      end
      it 'correctly excludes any packages that match a passed excludes argument' do
        expect(Pkg::Util::Ship.collect_packages(['pkg/**/*.msi'], ['puppet-agent-x(86|64).msi'])).not_to include('pkg/windows/puppet5/puppet-agent-x86.msi')
      end
      it 'correctly includes packages that do not match a passed excluded argument' do
        expect(Pkg::Util::Ship.collect_packages(['pkg/**/*.msi'], ['puppet-agent-x(86|64).msi'])).to \
          match_array(
            [
              'pkg/windows/puppet5/puppet-agent-1.4.1.2904.g8023dd1-x86.msi',
              'pkg/windowsfips/puppet5/puppet-agent-1.4.1.2904.g8023dd1-x64.msi',
            ]
          )
      end
    end

    it 'fails when it cannot find any packages at all' do
      allow(Dir).to receive(:glob).with('pkg/**/*.html').and_return([])
      expect(Pkg::Util::Ship.collect_packages(['pkg/**/*.html'])).to be_empty
    end
  end

local_pkgs = [
  'pkg/deb/stretch/puppet5/puppet-agent_1.4.1.2904.g8023dd1-1stretch_i386.deb',
  'pkg/el/5/puppet5/x86_64/puppet-agent-1.4.1.2904.g8023dd1-1.el5.x86_64.rpm',
  'pkg/sles/12/puppet5/x86_64/puppet-agent-1.4.1.2904.g8023dd1-1.sles12.x86_64.rpm',
  'pkg/mac/10.15/puppet5/x86_64/puppet-agent-1.4.1.2904.g8023dd1-1.osx10.15.dmg',
  'pkg/windows/puppet5/puppet-agent-1.4.1.2904.g8023dd1-x86.msi',
]
new_pkgs = [
  'pkg/stretch/puppet5/puppet-agent_1.4.1.2904.g8023dd1-1stretch_i386.deb',
  'pkg/puppet5/el/5/x86_64/puppet-agent-1.4.1.2904.g8023dd1-1.el5.x86_64.rpm',
  'pkg/puppet5/sles/12/x86_64/puppet-agent-1.4.1.2904.g8023dd1-1.sles12.x86_64.rpm',
  'pkg/mac/puppet5/10.15/x86_64/puppet-agent-1.4.1.2904.g8023dd1-1.osx10.15.dmg',
  'pkg/windows/puppet5/puppet-agent-1.4.1.2904.g8023dd1-x86.msi',
]

  describe '#reorganize_packages' do
    tmpdir = Dir.mktmpdir

    before :each do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet5')
      expect(FileUtils).to receive(:cp).at_least(:once)
    end

    it 'makes a temporary directory' do
      expect(FileUtils).to receive(:mkdir_p).at_least(:once)
      Pkg::Util::Ship.reorganize_packages(local_pkgs, tmpdir)
    end

    it 'leaves the old packages in place' do
      orig = local_pkgs
      Pkg::Util::Ship.reorganize_packages(local_pkgs, tmpdir)
      expect(local_pkgs).to eq(orig)
    end

    it 'returns a list of packages that do not have the temp dir in the path' do
      expect(Pkg::Util::Ship.reorganize_packages(local_pkgs, tmpdir)).to eq(new_pkgs)
    end
  end

  describe '#ship_pkgs' do
    test_staging_server = 'foo.delivery.puppetlabs.net'
    test_remote_path = '/opt/repository/yum'

    it 'ships the packages to the staging server' do
      allow(Pkg::Util::Ship).to receive(:collect_packages).and_return(local_pkgs)
      allow(Pkg::Util::Ship).to receive(:reorganize_packages).and_return(new_pkgs)
      allow(Pkg::Util).to receive(:ask_yes_or_no).and_return(true)
      # All of these expects must be called in the same block in order for the
      # tests to work without actually shipping anything
      expect(Pkg::Util::Net).to receive(:remote_ssh_cmd).with(test_staging_server, /#{test_remote_path}/).exactly(local_pkgs.count).times
      expect(Pkg::Util::Net).to receive(:rsync_to).with(anything, test_staging_server, /#{test_remote_path}/, anything).exactly(local_pkgs.count).times
      expect(Pkg::Util::Net).to receive(:remote_set_ownership).with(test_staging_server, 'root', 'release', anything).exactly(local_pkgs.count).times
      expect(Pkg::Util::Net).to receive(:remote_set_permissions).with(test_staging_server, '775', anything).exactly(local_pkgs.count).times
      expect(Pkg::Util::Net).to receive(:remote_set_permissions).with(test_staging_server, '0664', anything).exactly(local_pkgs.count).times
      expect(Pkg::Util::Net).to receive(:remote_set_immutable).with(test_staging_server, anything).exactly(local_pkgs.count).times
      expect(Pkg::Util::Ship.ship_pkgs(['pkg/**/*.rpm'], test_staging_server, test_remote_path)).to eq(true)
    end

    it 'ships packages containing the string `pkg` to the right place' do
      allow(Pkg::Util::Ship).to receive(:collect_packages).and_return(['pkg/el/5/puppet5/x86_64/my-super-sweet-pkg-1.0.0-1.el5.x86_64.rpm' ])
      allow(Pkg::Util::Ship).to receive(:reorganize_packages).and_return(['pkg/puppet5/el/5/x86_64/my-super-sweet-pkg-1.0.0-1.el5.x86_64.rpm'])
      allow(Pkg::Util).to receive(:ask_yes_or_no).and_return(true)
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/test')
      # All of these expects must be called in the same block in order for the
      # tests to work without actually shipping anything
      expect(Pkg::Util::Net).to receive(:remote_ssh_cmd).with(test_staging_server, /#{test_remote_path}/)
      expect(Pkg::Util::Net).to receive(:rsync_to).with(anything, test_staging_server, /#{test_remote_path}/, anything)
      expect(Pkg::Util::Net).to receive(:remote_set_ownership).with(test_staging_server, 'root', 'release', ['/opt/repository/yum/puppet5/el/5/x86_64', '/opt/repository/yum/puppet5/el/5/x86_64/my-super-sweet-pkg-1.0.0-1.el5.x86_64.rpm'])
      expect(Pkg::Util::Net).to receive(:remote_set_permissions).with(test_staging_server, '775', anything)
      expect(Pkg::Util::Net).to receive(:remote_set_permissions).with(test_staging_server, '0664', anything)
      expect(Pkg::Util::Net).to receive(:remote_set_immutable).with(test_staging_server, anything)
      expect(Pkg::Util::Ship.ship_pkgs(['pkg/**/*.rpm'], test_staging_server, test_remote_path, excludes: ['puppet-agent'])).to eq(true)
    end

    it 'returns false if there are no packages to ship' do
      expect(Pkg::Util::Ship.ship_pkgs(['pkg/**/*.msi'], test_staging_server, test_remote_path)).to eq(false)
    end
  end
end
