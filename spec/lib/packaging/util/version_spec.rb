# -*- ruby -*-
require 'spec_helper'

# Spec tests for Pkg::Util::Version
describe 'Pkg::Util::Version' do
  context '#versionbump' do
    let(:version_file) { 'thing.txt' }
    let(:version) { '1.2.3' }
    let(:orig_contents) { "abcd\nVERSION = @DEVELOPMENT_VERSION@\n" }
    let(:updated_contents) { "abcd\nVERSION = #{version}\n" }

    it "should update the version file contents accordingly" do
      Pkg::Config.config_from_hash({:project => "foo", :version_file => version_file})
      allow(IO).to receive(:read).with(version_file) { orig_contents }
      allow(Pkg::Config).to receive(:version) { version }
      version_file_to_write = double('file')
      expect(File).to receive(:open).with(version_file, 'w').and_yield(version_file_to_write)
      expect(version_file_to_write).to receive(:write).with(updated_contents)
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

end
