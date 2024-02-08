require 'spec_helper'

describe 'Pkg::Rpm::Repo' do
  let(:wget)          { '/opt/tools/bin/wget' }
  let(:builds_server) { 'saturn.puppetlabs.net' }
  let(:project)       { 'rpm_repos' }
  let(:ref)           { '1234abcd' }
  let(:base_url)      { "http://#{builds_server}/#{project}/#{ref}" }
  let(:mocks)         { ['el-5-i386', 'el-5-x86_64', 'el-5-SRPMS'] }
  let(:wget_results) do
    mocks.map do |mock|
      dist, version, arch = mock.split('-')
      "http://#{builds_server}/#{project}/#{ref}/repos/#{dist}/#{version}/products/#{arch}/repodata/"
    end.join("\n")
  end
  let(:wget_garbage) { "\nother things\n and an index\nhttp://somethingelse.com" }
  let(:repo_configs) do
    mocks.map { |mock| "pkg/repo_configs/rpm/pl-#{project}-#{ref}-#{mock}.repo" }
  end

  # Setup and tear down for the tests
  around do |example|
    orig_server = Pkg::Config.builds_server
    orig_host = Pkg::Config.distribution_server
    orig_project = Pkg::Config.project
    orig_ref = Pkg::Config.ref
    orig_repo_path = Pkg::Config.jenkins_repo_path
    Pkg::Config.builds_server = builds_server
    Pkg::Config.project = project
    Pkg::Config.ref = ref
    example.run
    Pkg::Config.builds_server = orig_server
    Pkg::Config.distribution_server = orig_host
    Pkg::Config.project = orig_project
    Pkg::Config.ref = orig_ref
    Pkg::Config.jenkins_repo_path = orig_repo_path
  end

  describe '#generate_repo_configs' do
    it 'fails if wget isn\'t available' do
      allow(Pkg::Util::Tool)
        .to receive(:find_tool)
        .with('wget', { required: true })
        .and_return false
      expect { Pkg::Rpm::Repo.generate_repo_configs }.to raise_error(RuntimeError)
    end

    it 'warns if there are no rpm repos available for the build' do
      expect(Pkg::Util::Tool)
        .to receive(:find_tool)
        .with('wget', { required: true })
        .and_return(wget)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{wget} --spider -r -l 5 --no-parent #{base_url}/repos/ 2>&1")
        .and_return('')
      expect(Pkg::Rpm::Repo)
        .to receive(:warn)
        .with("No rpm repos were found to generate configs from!")
      Pkg::Rpm::Repo.generate_repo_configs
    end

    it 'writes the expected repo configs to disk' do
      expect(Pkg::Util::Tool)
        .to receive(:find_tool)
        .with('wget', { required: true })
        .and_return(wget)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{wget} --spider -r -l 5 --no-parent #{base_url}/repos/ 2>&1")
        .and_return(wget_results + wget_garbage)
      wget_results.split.each do |result|
        cur_result = result.chomp('repodata/')
        expect(Pkg::Util::Execution)
          .to receive(:capture3)
          .with("#{wget} --spider -r -l 1 --no-parent #{cur_result} 2>&1")
          .and_return("#{cur_result}/thing.rpm")
      end
      expect(FileUtils).to receive(:mkdir_p).with("pkg/repo_configs/rpm")
      config = []
      repo_configs.each_with_index do |repo_config, i|
        expect(Pkg::Paths).to receive(:tag_from_artifact_path).and_return(mocks[i])
        expect(Pkg::Platforms).to receive(:parse_platform_tag).and_return(mocks[i].split('-'))
        config[i] = double(File)
        expect(File).to receive(:open).with(repo_config, 'w').and_yield(config[i])
        expect(config[i]).to receive(:puts)
      end
      Pkg::Rpm::Repo.generate_repo_configs
    end
  end

  describe "#retrieve_repo_configs" do
    it "fails if there are no deb repos available for the build" do
      expect(Pkg::Util::Tool)
        .to receive(:find_tool)
        .with('wget', { required: true })
        .and_return(wget)
      expect(FileUtils).to receive(:mkdir_p).with('pkg/repo_configs').and_return(true)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with(%r{#{wget}.*/repo_configs/rpm})
        .and_raise(RuntimeError)
      expect { Pkg::Rpm::Repo.retrieve_repo_configs }
        .to raise_error(RuntimeError, %r{failed\.$})
    end
  end

  describe '#create_local_repos' do
    let(:command) { '/usr/bin/make some repos' }
    let(:target_directory) { '/tmp/dir/thing' }

    it 'makes a repo in the target directory' do
      expect(Pkg::Rpm::Repo)
        .to receive(:repo_creation_command)
        .with(target_directory)
        .and_return('run this thing')
      expect(Pkg::Util::Execution).to receive(:capture3).with("bash -c 'run this thing'")
      Pkg::Rpm::Repo.create_local_repos(target_directory)
    end
  end

  describe '#create_remote_repos' do
    let(:command) { '/usr/bin/make some repos' }
    let(:artifact_directory) { '/tmp/dir/thing' }
    let(:pkg_directories) { ['el-6-i386', 'el/7/x86_64'] }

    it 'makes a repo in the target directory' do
      allow(File).to receive(:join).and_return(artifact_directory)
      expect(Pkg::Repo).to receive(:directories_that_contain_packages).and_return(pkg_directories)
      expect(Pkg::Repo).to receive(:populate_repo_directory)
      expect(Pkg::Rpm::Repo).to receive(:repo_creation_command).and_return(command)
      expect(Pkg::Util::Net)
        .to receive(:remote_execute)
        .with(Pkg::Config.distribution_server, command)
      expect(Pkg::Rpm::Repo).to receive(:generate_repo_configs)
      expect(Pkg::Rpm::Repo).to receive(:ship_repo_configs)
      expect(Pkg::Util::Net)
        .to receive(:remote_execute)
        .with(Pkg::Config.distribution_server, "rm -f #{artifact_directory}/repos/.lock")
      Pkg::Rpm::Repo.create_remote_repos
    end
  end

  describe '#ship_repo_configs' do
    it 'warn if there are no repo configs to ship' do
      Pkg::Config.jenkins_repo_path = '/a/b/c/d'
      expect(Dir).to receive(:exist?).with("pkg/repo_configs/rpm").and_return(true)
      expect(Dir).to receive(:empty?).with("pkg/repo_configs/rpm").and_return(true)
      expect(Pkg::Rpm::Repo)
        .to receive(:warn)
        .with(/^No repo_configs found in.*Skipping repo shipping/)
      Pkg::Rpm::Repo.ship_repo_configs
    end

    it 'ships repo configs to the build server' do
      Pkg::Config.jenkins_repo_path = '/a/b/c/d'
      Pkg::Config.project = 'thing2'
      Pkg::Config.ref = 'abcd1234'
      Pkg::Config.distribution_server = 'a.host.that.wont.exist'
      repo_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/repo_configs/rpm"
      expect(Dir).to receive(:exist?).with("pkg/repo_configs/rpm").and_return(true)
      expect(Dir).to receive(:empty?).with("pkg/repo_configs/rpm").and_return(false)
      expect(Pkg::Util::RakeUtils).to receive(:invoke_task).with('pl:fetch')
      expect(Pkg::Util::Net)
        .to receive(:remote_execute)
        .with(Pkg::Config.distribution_server, "mkdir -p #{repo_dir}")
      expect(Pkg::Util::Execution).to receive(:retry_on_fail).with(times: 3)
      Pkg::Rpm::Repo.ship_repo_configs
    end
  end
end
