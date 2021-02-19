require 'spec_helper'

describe '#Pkg::Util::Ship' do
  describe '#collect_packages' do
    msi_packages = %w[
      pkg/windows/puppet6/puppet-agent-6.19.0-x64.msi
      pkg/windows/puppet6/puppet-agent-6.19.0-x86.msi
      pkg/windowsfips/puppet6/puppet-agent-6.19.0-x64.msi
      pkg/windows/puppet6/puppet-agent-x86.msi
      pkg/windowsfips/puppet6/puppet-agent-x64.msi
    ]
    solaris_packages = %w[
      pkg/solaris/10/puppet6/puppet-agent-6.9.0-1.sparc.pkg.gz
      pkg/solaris/10/puppet6/puppet-agent-6.9.0-1.sparc.pkg.gz.asc
    ]

    it 'returns an array of packages found on the filesystem' do
      allow(Dir).to receive(:glob).with('pkg/**/*.sparc*').and_return(solaris_packages)
      expect(Pkg::Util::Ship.collect_packages(['pkg/**/*.sparc*'])).to eq(solaris_packages)
    end

    context 'excluding packages' do
      before :each do
        allow(Dir).to receive(:glob).with('pkg/**/*.msi').and_return(msi_packages)
      end
      it 'correctly excludes any packages that match a passed excludes argument' do
        expect(Pkg::Util::Ship.collect_packages(['pkg/**/*.msi'], ['puppet-agent-x(86|64).msi']))
          .not_to include('pkg/windows/puppet6/puppet-agent-x86.msi')
        expect(Pkg::Util::Ship.collect_packages(['pkg/**/*.msi'], ['puppet-agent-x(86|64).msi']))
          .not_to include('pkg/windows/puppet6/puppet-agent-x64.msi')
      end
      it 'correctly includes packages that do not match a passed excluded argument' do
        expect(Pkg::Util::Ship.collect_packages(['pkg/**/*.msi'],
                                                ['bogus-puppet-agent-x(86|64).msi']))
          .to match_array(msi_packages)
      end
    end

    it 'returns an empty array when it cannot find any packages' do
      allow(Dir).to receive(:glob).with('pkg/**/*.html').and_return([])
      expect(Pkg::Util::Ship.collect_packages(['pkg/**/*.html'])).to be_empty
    end
  end

  # Sample data for #reorganize_packages and #ship_pkgs specs
  retrieved_packages = %w[
    pkg/deb/bionic/puppet6/puppet-agent_6.19.0-1bionic_amd64.deb
    pkg/el/7/puppet6/aarch64/puppet-agent-6.19.0-1.el7.aarch64.rpm
    pkg/el/7/puppet6/ppc64le/puppet-agent-6.19.0-1.el7.ppc64le.rpm
    pkg/el/7/puppet6/x86_64/puppet-agent-6.19.0-1.el7.x86_64.rpm
    pkg/sles/12/puppet6/ppc64le/puppet-agent-6.19.0-1.sles12.ppc64le.rpm
    pkg/sles/12/puppet6/x86_64/puppet-agent-6.19.0-1.sles12.x86_64.rpm
    pkg/sles/15/puppet6/x86_64/puppet-agent-6.19.0-1.sles15.x86_64.rpm
    pkg/apple/10.14/puppet6/x86_64/puppet-agent-6.19.0-1.osx10.14.dmg
    pkg/apple/10.15/puppet6/x86_64/puppet-agent-6.19.0-1.osx10.15.dmg
    pkg/fedora/32/puppet6/x86_64/puppet-agent-6.19.0-1.fc32.x86_64.rpm
    pkg/windows/puppet-agent-6.19.0-x64.msi
    pkg/windows/puppet-agent-6.19.0-x86.msi
    pkg/windowsfips/puppet-agent-6.19.0-x64.msi
    pkg/windows/puppet6/puppet-agent-x86.msi
    pkg/windowsfips/puppet6/puppet-agent-x64.msi
  ]

  # After reorganization, the packages should look like this.
  # Beware apple->mac transforms.
  expected_reorganized_packages = %w[
    pkg/bionic/puppet6/puppet-agent_6.19.0-1bionic_amd64.deb
    pkg/puppet6/el/7/aarch64/puppet-agent-6.19.0-1.el7.aarch64.rpm
    pkg/puppet6/el/7/ppc64le/puppet-agent-6.19.0-1.el7.ppc64le.rpm
    pkg/puppet6/el/7/x86_64/puppet-agent-6.19.0-1.el7.x86_64.rpm
    pkg/puppet6/sles/12/ppc64le/puppet-agent-6.19.0-1.sles12.ppc64le.rpm
    pkg/puppet6/sles/12/x86_64/puppet-agent-6.19.0-1.sles12.x86_64.rpm
    pkg/puppet6/sles/15/x86_64/puppet-agent-6.19.0-1.sles15.x86_64.rpm
    pkg/mac/puppet6/10.14/x86_64/puppet-agent-6.19.0-1.osx10.14.dmg
    pkg/mac/puppet6/10.15/x86_64/puppet-agent-6.19.0-1.osx10.15.dmg
    pkg/puppet6/fedora/32/x86_64/puppet-agent-6.19.0-1.fc32.x86_64.rpm
    pkg/windows/puppet6/puppet-agent-6.19.0-x64.msi
    pkg/windows/puppet6/puppet-agent-6.19.0-x86.msi
    pkg/windowsfips/puppet6/puppet-agent-6.19.0-x64.msi
    pkg/windows/puppet6/puppet-agent-x86.msi
    pkg/windowsfips/puppet6/puppet-agent-x64.msi
  ]

  describe '#reorganize_packages' do
    # This is a sampling of packages found on builds.delivery.puppetlabs.net in
    # '/opt/jenkins-builds/puppet-agent/<version>/artifacts'
    # pl:jenkins:retrieve replaces 'artifacts' with 'pkg', so we pick up the
    # action from that point by pretending that we've scanned the directory and
    # made this list:

    scratch_directory = Dir.mktmpdir

    before :each do
      allow(Pkg::Config).to receive(:repo_name).and_return('puppet6')
      expect(FileUtils).to receive(:cp).at_least(:once).and_return(true)
    end

    original_packages = retrieved_packages

    it 'leaves the old packages in place' do
      reorganized_packages = Pkg::Util::Ship
                               .reorganize_packages(retrieved_packages, scratch_directory)

      expect(retrieved_packages).to eq(original_packages)
    end

    it 'returns a list of properly reorganized packages' do
      reorganized_packages = Pkg::Util::Ship
                               .reorganize_packages(retrieved_packages, scratch_directory)
      expect(reorganized_packages).to eq(expected_reorganized_packages)
    end
  end

  describe '#ship_pkgs' do
    test_staging_server = 'foo.delivery.puppetlabs.net'
    test_remote_path = '/opt/repository/yum'

    it 'ships the packages to the staging server' do
      allow(Pkg::Util::Ship)
        .to receive(:collect_packages)
              .and_return(retrieved_packages)
      allow(Pkg::Util::Ship)
        .to receive(:reorganize_packages)
              .and_return(expected_reorganized_packages)
      allow(Pkg::Util).to receive(:ask_yes_or_no).and_return(true)
      # All of these expects must be called in the same block in order for the
      # tests to work without actually shipping anything
      expect(Pkg::Util::Net)
        .to receive(:remote_execute)
              .with(test_staging_server, /#{test_remote_path}/)
              .exactly(retrieved_packages.count).times
      expect(Pkg::Util::Net)
        .to receive(:rsync_to)
              .with(anything, test_staging_server, /#{test_remote_path}/, anything)
              .exactly(retrieved_packages.count).times
      expect(Pkg::Util::Net)
        .to receive(:remote_set_ownership)
              .with(test_staging_server, 'root', 'release', anything)
              .exactly(retrieved_packages.count).times
      expect(Pkg::Util::Net)
        .to receive(:remote_set_permissions)
              .with(test_staging_server, '775', anything)
              .exactly(retrieved_packages.count).times
      expect(Pkg::Util::Net)
        .to receive(:remote_set_permissions)
              .with(test_staging_server, '0664', anything)
              .exactly(retrieved_packages.count).times
      expect(Pkg::Util::Net)
        .to receive(:remote_set_immutable)
              .with(test_staging_server, anything)
              .exactly(retrieved_packages.count).times
      expect(Pkg::Util::Ship.ship_pkgs(['pkg/**/*.rpm'], test_staging_server, test_remote_path))
        .to eq(true)
    end

    it 'ships packages containing the string `pkg` to the right place' do
      retrieved_package =   'pkg/el/7/puppet6/x86_64/puppet-agent-6.19.0-1.el7.x86_64.rpm'
      reorganized_package = 'pkg/puppet6/el/7/x86_64/puppet-agent-6.19.0-1.el7.x86_64.rpm'
      package_basename = File.basename(reorganized_package)
      repository_base_path = '/opt/repository/yum/puppet6/el/7/x86_64'

      allow(Pkg::Util::Ship).to receive(:collect_packages).and_return([retrieved_package])
      allow(Pkg::Util::Ship).to receive(:reorganize_packages).and_return([reorganized_package])
      allow(Pkg::Util).to receive(:ask_yes_or_no).and_return(true)
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/test')

      # All of these expects must be called in the same block in order for the
      # tests to work without actually shipping anything
      expect(Pkg::Util::Net)
        .to receive(:remote_execute)
              .with(test_staging_server, /#{test_remote_path}/)
      expect(Pkg::Util::Net)
        .to receive(:rsync_to)
              .with(anything, test_staging_server, /#{test_remote_path}/, anything)
      expect(Pkg::Util::Net)
        .to receive(:remote_set_ownership)
              .with(test_staging_server, 'root', 'release',
                    [repository_base_path, "#{repository_base_path}/#{package_basename}"])
      expect(Pkg::Util::Net)
        .to receive(:remote_set_permissions)
              .with(test_staging_server, '775', anything)
      expect(Pkg::Util::Net)
        .to receive(:remote_set_permissions)
              .with(test_staging_server, '0664', anything)
      expect(Pkg::Util::Net)
        .to receive(:remote_set_immutable)
              .with(test_staging_server, anything)
      expect(Pkg::Util::Ship.ship_pkgs(['pkg/**/*.rpm'], test_staging_server,
                                       test_remote_path, excludes: ['puppet-agent']))
        .to eq(true)
    end

    it 'returns false if there are no packages to ship' do
      expect(Pkg::Util::Ship.ship_pkgs(['pkg/**/*.msi'],
                                       test_staging_server, test_remote_path))
        .to eq(false)
    end
  end
end
