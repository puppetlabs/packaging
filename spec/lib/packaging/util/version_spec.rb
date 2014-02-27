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
end
