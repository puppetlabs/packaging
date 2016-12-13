# -*- ruby -*-
require 'spec_helper'

describe "Pkg::Util::Version" do
  context "#versionbump" do
    let(:version_file) { "thing.txt" }
    let(:version) { "1.2.3" }
    let(:orig_contents) { "abcd\nVERSION = @DEVELOPMENT_VERSION@\n" }
    let(:updated_contents) { "abcd\nVERSION = #{version}\n" }

    it "should update the version file contents accordingly" do
      Pkg::Config.config_from_hash({:project => "foo", :version_file => version_file})
      IO.stub(:read).with(version_file).and_return(orig_contents)
      Pkg::Config.stub(:version).and_return(version)
      version_file_to_write = double('file')
      File.should_receive(:open).with(version_file, 'w').and_yield(version_file_to_write)
      version_file_to_write.should_receive(:write).with(updated_contents)
      Pkg::Util::Version.versionbump
    end
  end

  context "#is_less_than_one?" do
    context "with a version that starts with '0'" do
      it "should return true" do
        Pkg::Util::Version.stub(:get_dash_version).and_return("0.0.1")
        Pkg::Util::Version.is_less_than_one?.should be(true)
      end
    end

    context "with a version that starts with '1' or greater" do
      it "should return false" do
        Pkg::Util::Version.stub(:get_dash_version).and_return("1.0.0")
        Pkg::Util::Version.is_less_than_one?.should be(false)
      end
    end
  end

  context "#git_sha_or_tag" do

    let(:sha) { "20a338b33e2fc1cbaee27b69de5eb2d06637a7c4" }
    let(:short_sha) { "20a338b" }
    let(:tag) { "2.0.4" }

    around do |example|
      orig_root = Pkg::Config.project_root
      Pkg::Config.project_root = Pkg::Util::File.mktemp
      example.run
      Pkg::Config.project_root = orig_root
    end

    it "returns a sha if the repo is not tagged" do
      Pkg::Util::Version.should_receive(:git_ref_type).and_return("sha")
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} rev-parse --short=40 HEAD").and_return(sha)
      Pkg::Util::Version.git_sha_or_tag
    end

    it "returns a short sha if the repo is not tagged and short is specified" do
      Pkg::Util::Version.should_receive(:git_ref_type).and_return("sha")
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} rev-parse --short=7 HEAD").and_return(short_sha)
      Pkg::Util::Version.git_sha_or_tag(7)
    end

    it "returns a tag if the repo is tagged" do
      Pkg::Util::Version.should_receive(:git_ref_type).and_return("tag")
      Pkg::Util::Execution.should_receive(:capture3).with("#{Pkg::Util::Tool::GIT} describe").and_return(tag)
      Pkg::Util::Version.git_sha_or_tag
    end
  end

  context "#is_final?" do

    context "with version_strategy 'rc_final'" do
      it "should use 'is_rc?' and return the opposite" do
        Pkg::Util::Version.stub(:is_rc?).and_return(false)
        Pkg::Config.stub(:version_strategy).and_return("rc_final")
        Pkg::Util::Version.should_receive(:is_rc?)
        Pkg::Util::Version.is_final?.should be(true)
      end
    end

    context "with version_strategy 'odd_even'" do
      it "should use 'is_odd?' and return the opposite" do
        Pkg::Util::Version.stub(:is_odd?).and_return(false)
        Pkg::Config.stub(:version_strategy).and_return("odd_even")
        Pkg::Util::Version.should_receive(:is_odd?)
        Pkg::Util::Version.is_final?.should be(true)
      end
    end

    context "with version_strategy 'zero_based'" do
      it "should use 'is_less_than_one?' and return the opposite" do
        Pkg::Util::Version.stub(:is_less_than_one?).and_return(false)
        Pkg::Config.stub(:version_strategy).and_return("zero_based")
        Pkg::Util::Version.should_receive(:is_less_than_one?)
        Pkg::Util::Version.is_final?.should be(true)
      end
    end
  end


  context "#tagged?" do
    it "reports Yes on tagged component" do
      expect(Pkg::Util::Version.tagged?("git://github.com/puppetlabs/leatherman.git", "refs/tags/0.6.2")).to be(true)
    end

    it "reports No on non-tagged component" do
      expect(Pkg::Util::Version.tagged?("git://github.com/puppetlabs/leatherman.git", "4eef05389ebf418b62af17406c7f9f13fa51f975")).to be(false)
    end
  end
end
