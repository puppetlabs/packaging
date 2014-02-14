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

  describe "hostname" do
    it "should return the hostname of the current host" do
      Socket.stub(:gethostname) { "foo" }
      Pkg::Util::Net.hostname.should eq("foo")
    end
  end

  describe "check_host" do
    context "with required :true" do
      it "should raise an exception if the passed host does not match the current host" do
        Socket.stub(:gethostname) { "foo" }
        Pkg::Util::Net.should_receive(:check_host).and_raise(RuntimeError)
        expect{ Pkg::Util::Net.check_host("bar", :required => true) }.to raise_error(RuntimeError)
      end
    end

    context "with required :false" do
      it "should return nil if the passed host does not match the current host" do
        Socket.stub(:gethostname) { "foo" }
        expect(Pkg::Util::Net.check_host("bar", :required => false)).to be_nil
      end
    end
  end
end
