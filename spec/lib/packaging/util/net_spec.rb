require 'spec_helper'

describe "Pkg::Util::Net" do
  let(:target)     { "/tmp/placething" }
  let(:target_uri) { "http://google.com" }
  let(:content)    { "stuff" }

  describe "#fetch_uri" do
    context "given a target directory" do
      it "does nothing if the directory isn't writable" do
        File.stub(:writable?).with(File.dirname(target)) { false }
        File.should_receive(:open).never
        Pkg::Util::Net.fetch_uri(target_uri, target)
      end

      it "writes the content of the uri to a file if directory is writable" do
        File.should_receive(:writable?).once.with(File.dirname(target)) { true }
        File.should_receive(:open).once.with(target, 'w')
        Pkg::Util::Net.fetch_uri(target_uri, target)
      end
    end
  end
end
