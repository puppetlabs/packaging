require 'spec_helper'

describe "Pkg::Deb::Repo" do
  let(:wget)          { "/opt/tools/bin/wget" }
  let(:builds_server) { "saturn.puppetlabs.net" }
  let(:project)       { "deb_repos" }
  let(:ref)           { "1234abcd" }
  let(:base_url)      { "http://#{builds_server}/#{project}/#{ref}" }
  let(:cows)          { ["xenial", "jessie", "stretch", ""] }
  let(:wget_results)  { cows.map {|cow| "#{base_url}/repos/apt/#{cow}" }.join("\n") }
  let(:wget_garbage)  { "\n and an index\nhttp://somethingelse.com/robots" }
  let(:repo_configs)  { cows.reject {|cow| cow.empty?}.map {|dist| "pkg/repo_configs/deb/pl-#{project}-#{ref}-#{dist}.list" } }

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

  describe "#generate_repo_configs" do
    it "fails if wget isn't available" do
      Pkg::Util::Tool.should_receive(:find_tool).with("wget", {:required => true}).and_raise(RuntimeError)
      expect {Pkg::Deb::Repo.generate_repo_configs}.to raise_error(RuntimeError)
    end

    it "warns if there are no deb repos available for the build" do
      Pkg::Util::Tool.should_receive(:find_tool).with("wget", {:required => true}).and_return(wget)
      Pkg::Util::Execution.should_receive(:capture3).with("#{wget} --spider -r -l 1 --no-parent #{base_url}/repos/apt/ 2>&1").and_raise(RuntimeError)
      Pkg::Deb::Repo.should_receive(:warn).with("No debian repos available for #{project} at #{ref}.")
      Pkg::Deb::Repo.generate_repo_configs
    end

    it "writes the expected repo configs to disk" do
      Pkg::Util::Tool.should_receive(:find_tool).with("wget", {:required => true}).and_return(wget)
      Pkg::Util::Execution.should_receive(:capture3).with("#{wget} --spider -r -l 1 --no-parent #{base_url}/repos/apt/ 2>&1").and_return(wget_results + wget_garbage)
      FileUtils.should_receive(:mkdir_p).with("pkg/repo_configs/deb")
      config = []
      repo_configs.each_with_index do |repo_config, i|
        config[i] = double(File)
        File.should_receive(:open).with(repo_config, 'w').and_yield(config[i])
        config[i].should_receive(:puts)
      end
      Pkg::Deb::Repo.generate_repo_configs
    end
  end

  describe "#retrieve_repo_configs" do
    it "fails if wget isn't available" do
      Pkg::Util::Tool.should_receive(:find_tool).with("wget", {:required => true}).and_raise(RuntimeError)
      expect {Pkg::Deb::Repo.generate_repo_configs}.to raise_error(RuntimeError)
    end

    it "warns if there are no deb repos available for the build" do
      Pkg::Util::Tool.should_receive(:find_tool).with("wget", {:required => true}).and_return(wget)
      FileUtils.should_receive(:mkdir_p).with("pkg/repo_configs").and_return(true)
      Pkg::Util::Execution.should_receive(:capture3).with("#{wget} -r -np -nH --cut-dirs 3 -P pkg/repo_configs --reject 'index*' #{base_url}/repo_configs/deb/").and_raise(RuntimeError)
      expect {Pkg::Deb::Repo.retrieve_repo_configs}.to raise_error(RuntimeError, /Couldn't retrieve deb apt repo configs/)
    end
  end

  describe "#repo_creation_command" do
    let(:prefix) { "thing" }
    let(:artifact_directory) { ["/a/b/c/xenial"] }

    it "returns a command to make repos" do
      command = Pkg::Deb::Repo.repo_creation_command(prefix, artifact_directory)
      command.should match(/reprepro/)
      command.should match(/#{prefix}/)
      command.should match(/#{artifact_directory}/)
    end
  end

  describe "#create_repos" do
    let(:command) { "/usr/bin/make some repos" }
    let(:artifact_directory) { "/tmp/dir/thing" }
    let(:pkg_directories) { ['place/to/deb/xenial', 'other/deb/trusty'] }

    it "generates repo configs remotely and then ships them" do
      File.stub(:join) {artifact_directory}
      Pkg::Repo.should_receive(:directories_that_contain_packages).and_return(pkg_directories)
      Pkg::Repo.should_receive(:populate_repo_directory)
      Pkg::Deb::Repo.should_receive(:repo_creation_command).and_return(command)
      Pkg::Util::Net.should_receive(:remote_ssh_cmd).with(Pkg::Config.distribution_server, command)
      Pkg::Deb::Repo.should_receive(:generate_repo_configs)
      Pkg::Deb::Repo.should_receive(:ship_repo_configs)
      Pkg::Util::Net.should_receive(:remote_ssh_cmd).with(Pkg::Config.distribution_server, "rm -f #{artifact_directory}/repos/.lock" )
      Pkg::Deb::Repo.create_repos
    end
  end

  describe "#ship_repo_configs" do
    it "warns if there are no repo configs to ship" do
      File.should_receive(:exist?).with("pkg/repo_configs/deb").and_return(true)
      Pkg::Util::File.should_receive(:empty_dir?).with("pkg/repo_configs/deb").and_return(true)
      Pkg::Deb::Repo.should_receive(:warn).with("No repo configs have been generated! Try pl:deb_repo_configs.")
      Pkg::Deb::Repo.ship_repo_configs
    end

    it "ships repo configs to the build server" do
      File.should_receive(:exist?).with("pkg/repo_configs/deb").and_return(true)
      Pkg::Config.jenkins_repo_path = "/a/b/c/d"
      Pkg::Config.distribution_server = "a.host.that.wont.exist"
      repo_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/repo_configs/deb"
      Pkg::Util::File.should_receive(:empty_dir?).with("pkg/repo_configs/deb").and_return(false)
      Pkg::Util::RakeUtils.should_receive(:invoke_task).with("pl:fetch")
      Pkg::Util::Net.should_receive(:remote_ssh_cmd).with(Pkg::Config.distribution_server, "mkdir -p #{repo_dir}")
      Pkg::Util::Execution.should_receive(:retry_on_fail).with(:times => 3)
      Pkg::Deb::Repo.ship_repo_configs
    end
  end

  describe "#sign_repos" do
    it "fails without reprepro" do
      Pkg::Util::Tool.should_receive(:find_tool).with('reprepro', {:required => true}).and_raise(RuntimeError)
      expect { Pkg::Deb::Repo.sign_repos }.to raise_error(RuntimeError)
    end

    it "makes a repo for each dist" do
      # stub out start_keychain to prevent actual keychain starts.
      Pkg::Util::Gpg.stub(:start_keychain)

      dists = cows.reject { |cow| cow.empty? }
      distfiles = {}
      Pkg::Util::File.should_receive(:directories).with("repos/apt").and_return(dists)

      # Let the keychain command happen if find_tool('keychain') finds it
      keychain_command = "/usr/bin/keychain -k mine"
      allow(Pkg::Util::Execution).to receive(:capture3) { keychain_command }

      # Enforce reprepro
      reprepro_command = "/bin/reprepro"
      Pkg::Util::Tool.should_receive(:check_tool).with("reprepro").and_return(reprepro_command)
      Pkg::Util::Execution.should_receive(:capture3).at_least(1).times.with("#{reprepro_command} -vvv --confdir ./conf --dbdir ./db --basedir ./ export")

      dists.each do |dist|
        distfiles[dist] = double
        Dir.should_receive(:chdir).with("repos/apt/#{dist}").and_yield
        File.should_receive(:open).with("conf/distributions", "w").and_yield(distfiles[dist])
        distfiles[dist].should_receive(:puts)
      end

      Pkg::Deb::Repo.sign_repos
    end
  end
end
