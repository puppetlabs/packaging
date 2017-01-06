# -*- ruby -*-
require 'spec_helper'

describe "Pkg::Util::Git" do
  context "#git_commit_file" do
    let(:file) {"thing.txt"}
    let(:message) {"foo"}

    it "should commit a file with no message, giving changes as the message instead" do
      Pkg::Util::Version.should_receive(:is_git_repo?).and_return(true)
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} diff HEAD #{file}")
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} commit #{file} -m \"Commit changes in #{file}\" &> /dev/null")
      Pkg::Util::Git.git_commit_file(file)
    end

    it "should commit a file with foo as message" do
      Pkg::Util::Version.should_receive(:is_git_repo?).and_return(true)
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} diff HEAD #{file}")
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} commit #{file} -m \"Commit #{message} in #{file}\" &> /dev/null")
      Pkg::Util::Git.git_commit_file(file, message)
    end
  end

  context "#git_tag" do
    let(:version) { "1.2.3" }
    let(:gpg_key) {"1231242354asdfawd"}
    around do |example|
      prev_gpg_key = Pkg::Config.gpg_key
      Pkg::Config.gpg_key = gpg_key
      example.run
      Pkg::Config.gpg_key = prev_gpg_key
    end

    it "should not fail" do
      Pkg::Util::Version.should_receive(:is_git_repo?).and_return(true)
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} tag -s -u #{gpg_key} -m '#{version}' #{version}")
      Pkg::Util::Git.should_not raise_error
      Pkg::Util::Git.git_tag(version)
    end
  end

  context "#git_bundle" do
    let(:treeish) { "foo" }
    let(:appendix) { "append" }
    let(:output_dir) { "/path/to/place" }
    let(:version) {"1.2.3"}
    let(:project) {"fooproj"}
    let(:string) {"bar"}
    let(:temp) {"/other/path/to/place" }
    around do |example|
      prev_project = Pkg::Config.project
      prev_version = Pkg::Config.version
      Pkg::Config.project = project
      Pkg::Config.version = version
      example.run
      Pkg::Config.project = prev_project
      Pkg::Config.version = prev_version
    end

    it "should create a git bundle with random appendix and random output directory" do
      Pkg::Util::Version.should_receive(:is_git_repo?).and_return(true)
      Pkg::Util::File.should_receive(:mktemp).and_return(temp)
      Pkg::Util.should_receive(:rand_string).and_return(string)
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} bundle create #{temp}/#{project}-#{version}-#{string} #{treeish} --tags")
      Dir.should_receive(:chdir).with(temp)
      Pkg::Util::Git.git_bundle(treeish)
    end

    it "should create a git bundle with random output directory" do
      Pkg::Util::Version.should_receive(:is_git_repo?).and_return(true)
      Pkg::Util::File.should_receive(:mktemp).and_return(temp)
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} bundle create #{temp}/#{project}-#{version}-#{appendix} #{treeish} --tags")
      Dir.should_receive(:chdir).with(temp)
      Pkg::Util::Git.git_bundle(treeish, appendix)
    end

    it "should create a git bundle" do
      Pkg::Util::Version.should_receive(:is_git_repo?).and_return(true)
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} bundle create #{output_dir}/#{project}-#{version}-#{appendix} #{treeish} --tags")
      Dir.should_receive(:chdir).with(output_dir)
      Pkg::Util::Git.git_bundle(treeish, appendix, output_dir)
    end
  end

  context "#git_pull" do
    let(:remote) {"rand.url"}
    let(:branch) {"foo"}

    it "should pull the branch" do
      Pkg::Util::Version.should_receive(:is_git_repo?).and_return(true)
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} pull #{remote} #{branch}")
      Pkg::Util::Git.git_pull(remote, branch)
    end
  end
end

