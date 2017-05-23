# -*- ruby -*-
require 'spec_helper'
describe "#Pkg::Repo" do
  let(:platform_repo_stub) do
    [
      {"name"=>"el-4-i386", "repo_location"=>"repos/el/4/**/i386"},
      {"name"=>"el-5-i386", "repo_location"=>"repos/el/5/**/i386"},
      {"name"=>"el-6-i386", "repo_location"=>"repos/el/6/**/i386"}
    ]
  end
  describe "#create_signed_repo_archive" do
    it "should change to the correct dir" do
      allow(Pkg::Util::Tool).to receive(:check_tool).and_return("tarcommand")
      allow(Pkg::Config).to receive(:project).and_return("project")
      allow(Pkg::Util::Version).to receive(:dot_version).and_return("1.1.1")
      allow(Pkg::Util::File).to receive(:empty_dir?).and_return(false)
      allow(Pkg::Util::Execution).to receive(:capture3)

      expect(Dir).to receive(:chdir).with("pkg").and_yield
      expect(Dir).to receive(:chdir).with("project/1.1.1").and_yield
      Pkg::Repo.create_signed_repo_archive("/path", "project-debian-6-i386", "version")
    end

    it "should use a ref if ref is specified as versioning" do
      allow(Pkg::Util::Tool).to receive(:check_tool).and_return("tarcommand")
      allow(Dir).to receive(:chdir).with("pkg").and_yield
      allow(Pkg::Util::File).to receive(:empty_dir?).and_return(false)
      allow(Pkg::Util::Execution).to receive(:capture3)

      expect(Pkg::Config).to receive(:project).and_return("project")
      expect(Pkg::Config).to receive(:ref).and_return("AAAAAAAAAAAAAAA")
      expect(Dir).to receive(:chdir).with("project/AAAAAAAAAAAAAAA").and_yield
      Pkg::Repo.create_signed_repo_archive("/path", "project-debian-6-i386", "ref")
    end

    it "should use dot versions if version is specified as versioning" do
      allow(Pkg::Util::Tool).to receive(:check_tool).and_return("tarcommand")
      allow(Dir).to receive(:chdir).with("pkg").and_yield
      allow(Pkg::Util::File).to receive(:empty_dir?).and_return(false)
      allow(Pkg::Util::Execution).to receive(:capture3)

      expect(Pkg::Config).to receive(:project).and_return("project")
      expect(Pkg::Util::Version).to receive(:dot_version).and_return("1.1.1")
      expect(Dir).to receive(:chdir).with("project/1.1.1").and_yield
      Pkg::Repo.create_signed_repo_archive("/path", "project-debian-6-i386", "version")
    end

    it "should fail if ENV['FAIL_ON_MISSING_TARGET'] is true and empty_dir? is also true" do
      allow(Pkg::Util::Tool).to receive(:check_tool).and_return("tarcommand")
      allow(Pkg::Config).to receive(:project).and_return("project")
      allow(Pkg::Util::Version).to receive(:dot_version).and_return("1.1.1")
      allow(Pkg::Util::Execution).to receive(:capture3)
      allow(Dir).to receive(:chdir).with("pkg").and_yield
      allow(Dir).to receive(:chdir).with("project/1.1.1").and_yield
      allow(Pkg::Util::File).to receive(:empty_dir?).and_return(true)
      ENV['FAIL_ON_MISSING_TARGET'] = "true"

      expect{Pkg::Repo.create_signed_repo_archive("/path", "project-debian-6-i386", "version")}.to raise_error(RuntimeError, "ERROR: missing packages under /path")
    end

    it "should only warn if ENV['FAIL_ON_MISSING_TARGET'] is false and empty_dir? is true" do
      allow(Pkg::Util::Tool).to receive(:check_tool).and_return("tarcommand")
      allow(Pkg::Config).to receive(:project).and_return("project")
      allow(Pkg::Util::Version).to receive(:dot_version).and_return("1.1.1")
      allow(Pkg::Util::Execution).to receive(:capture3)
      allow(Dir).to receive(:chdir).with("pkg").and_yield
      allow(Dir).to receive(:chdir).with("project/1.1.1").and_yield
      allow(Pkg::Util::File).to receive(:empty_dir?).and_return(true)
      ENV['FAIL_ON_MISSING_TARGET'] = "false"

      expect{Pkg::Repo.create_signed_repo_archive("/path", "project-debian-6-i386", "version")}.not_to raise_error
    end

    it "should invoke tar correctly" do
      allow(Pkg::Util::Tool).to receive(:check_tool).and_return("tarcommand")
      allow(Pkg::Config).to receive(:project).and_return("project")
      allow(Pkg::Util::Version).to receive(:dot_version).and_return("1.1.1")
      allow(Dir).to receive(:chdir).with("pkg").and_yield
      allow(Dir).to receive(:chdir).with("project/1.1.1").and_yield
      allow(Pkg::Util::File).to receive(:empty_dir?).and_return(false)

      expect(Pkg::Util::Execution).to receive(:capture3).with("tarcommand --owner=0 --group=0 --create --gzip --file repos/project-debian-6-i386.tar.gz /path")
      Pkg::Repo.create_signed_repo_archive("/path", "project-debian-6-i386", "version")
    end
  end

  describe "#create_signed_repo_archive" do
    it "should invoke create_signed_repo_archive correctly for multiple entries in platform_repos" do
      allow(Pkg::Config).to receive(:platform_repos).and_return(platform_repo_stub)

      expect(Pkg::Repo).to receive(:create_signed_repo_archive).with("repos/el/4/**/i386", "project-el-4-i386", "version")
      expect(Pkg::Repo).to receive(:create_signed_repo_archive).with("repos/el/5/**/i386", "project-el-5-i386", "version")
      expect(Pkg::Repo).to receive(:create_signed_repo_archive).with("repos/el/6/**/i386", "project-el-6-i386", "version")
      Pkg::Repo.create_all_repo_archives("project", "version")
    end
  end
end
