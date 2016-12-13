require 'spec_helper'

describe "Pkg::Rpm::Repo" do
  let(:wget)          { "/opt/tools/bin/wget" }
  let(:builds_server) { "saturn.puppetlabs.net" }
  let(:project)       { "rpm_repos" }
  let(:ref)           { "1234abcd" }
  let(:base_url)      { "http://#{builds_server}/#{project}/#{ref}" }
  let(:mocks)         { ["el-5-i386", "el-5-x86_64", "el-5-SRPMS"] }
  let(:wget_results)  {
                        mocks.map do |mock|
                          dist, version, arch = mock.split('-')
                          "http://#{builds_server}/#{project}/#{ref}/repos/#{dist}/#{version}/products/#{arch}/repodata/"
                        end.join("\n")
                      }
  let(:wget_garbage)  { "\nother things\n and an index\nhttp://somethingelse.com" }
  let(:repo_configs)  { mocks.map { |mock| "pkg/repo_configs/rpm/pl-#{project}-#{ref}-#{mock}.repo" } }

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
      Pkg::Util::Tool.stub(:find_tool).with("wget", {:required => true}) {false}
      expect {Pkg::Rpm::Repo.generate_repo_configs}.to raise_error(RuntimeError)
    end

    it "warns if there are no rpm repos available for the build" do
      Pkg::Util::Tool.should_receive(:find_tool).with("wget", {:required => true}).and_return(wget)
      Pkg::Util::Execution.should_receive(:capture3).with("#{wget} --spider -r -l 5 --no-parent #{base_url}/repos/ 2>&1").and_return("")
      Pkg::Rpm::Repo.should_receive(:warn).with("No rpm repos were found to generate configs from!")
      Pkg::Rpm::Repo.generate_repo_configs
    end

    it "writes the expected repo configs to disk" do
      Pkg::Util::Tool.should_receive(:find_tool).with("wget", {:required => true}).and_return(wget)
      Pkg::Util::Execution.should_receive(:capture3).with("#{wget} --spider -r -l 5 --no-parent #{base_url}/repos/ 2>&1").and_return(wget_results + wget_garbage)
      wget_results.split.each do |result|
        cur_result = result.chomp('repodata/')
        Pkg::Util::Execution.should_receive(:capture3).with("#{wget} --spider -r -l 1 --no-parent #{cur_result} 2>&1").and_return("#{cur_result}/thing.rpm")
      end
      FileUtils.should_receive(:mkdir_p).with("pkg/repo_configs/rpm")
      config = []
      repo_configs.each_with_index do |repo_config, i|
        config[i] = double(File)
        File.should_receive(:open).with(repo_config, 'w').and_yield(config[i])
        config[i].should_receive(:puts)
      end
      Pkg::Rpm::Repo.generate_repo_configs
    end
  end

  describe "#retrieve_repo_configs" do
    it "fails if wget isn't available" do
      Pkg::Util::Tool.stub(:find_tool).with("wget", {:required => true}) {false}
      expect {Pkg::Rpm::Repo.generate_repo_configs}.to raise_error(RuntimeError)
    end

    it "fails if there are no deb repos available for the build" do
      Pkg::Util::Tool.should_receive(:find_tool).with("wget", {:required => true}).and_return(wget)
      FileUtils.should_receive(:mkdir_p).with("pkg/repo_configs").and_return(true)
      Pkg::Util::Execution.should_receive(:capture3).with("#{wget} -r -np -nH --cut-dirs 3 -P pkg/repo_configs --reject 'index*' #{base_url}/repo_configs/rpm/").and_raise(RuntimeError)
      expect {Pkg::Rpm::Repo.retrieve_repo_configs}.to raise_error(RuntimeError, /Couldn't retrieve rpm yum repo configs/)
    end
  end

  describe "#create_repos" do
    let(:command) { "/usr/bin/make some repos" }
    let(:target_directory) { "/tmp/dir/thing" }

    it "fails without createrepo" do
      Dir.should_receive(:chdir).with(target_directory).and_yield
      Pkg::Util::Tool.should_receive(:find_tool).with('createrepo', :required => true).and_raise(RuntimeError)
      expect { Pkg::Rpm::Repo.create_repos(target_directory) }.to raise_error(RuntimeError)
    end

    it "makes a repo in the target directory" do
      Dir.should_receive(:chdir).with(target_directory).and_yield
      Pkg::Util::Tool.should_receive(:find_tool).with('createrepo', :required => true).and_return(command)
      Pkg::Rpm::Repo.should_receive(:repo_creation_command).with(command).and_return("run this thing")
      Pkg::Util::Execution.should_receive(:capture3).with("bash -c 'run this thing'")
      Pkg::Rpm::Repo.create_repos(target_directory)
    end
  end

  describe "#ship_repo_configs" do
    it "warn if there are no repo configs to ship" do
      Pkg::Util::File.should_receive(:empty_dir?).with("pkg/repo_configs/rpm").and_return(true)
      Pkg::Rpm::Repo.should_receive(:warn).with("No repo configs have been generated! Try pl:rpm_repo_configs.")
      Pkg::Rpm::Repo.ship_repo_configs
    end

    it "ships repo configs to the build server" do
      Pkg::Config.jenkins_repo_path = "/a/b/c/d"
      Pkg::Config.project = "thing2"
      Pkg::Config.ref = "abcd1234"
      Pkg::Config.distribution_server = "a.host.that.wont.exist"
      repo_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/repo_configs/rpm"
      Pkg::Util::File.should_receive(:empty_dir?).with("pkg/repo_configs/rpm").and_return(false)
      Pkg::Rpm::Repo.should_receive(:invoke_task).with("pl:fetch")
      Pkg::Util::Net.should_receive(:remote_ssh_cmd).with(Pkg::Config.distribution_server, "mkdir -p #{repo_dir}")
      Pkg::Util::Execution.should_receive(:retry_on_fail).with(:times => 3)
      Pkg::Rpm::Repo.ship_repo_configs
    end
  end
end
