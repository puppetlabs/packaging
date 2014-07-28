require 'spec_helper'
require 'socket'

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

  describe "hostname utils" do

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
          Pkg::Util::Net.check_host("bar", :required => false).should be_nil
        end
      end
    end
  end

  describe "remote_ssh_cmd" do
    it "should fail if ssh is not present" do
      Pkg::Util::Tool.stub(:find_tool) { fail }
      Pkg::Util::Tool.should_receive(:check_tool).and_raise(RuntimeError)
      expect{ Pkg::Util::Net.remote_ssh_cmd("foo", "bar") }.to raise_error(RuntimeError)
    end

    it "should execute a command :foo on a host :bar" do
      Kernel.should_receive(:system).with("ssh -t foo 'bar'")
      Pkg::Util::Net.remote_ssh_cmd("foo", "bar")
    end

    it "should escape single quotes in the command" do
      Kernel.should_receive(:system).with("ssh -t foo 'b'\\''ar'")
      Pkg::Util::Net.remote_ssh_cmd("foo", "b'ar")
    end

    it "should raise an error if ssh fails" do
      Kernel.should_receive(:system).with("ssh -t foo 'bar'").and_raise(RuntimeError)
      expect{ Pkg::Util::Net.remote_ssh_cmd("foo", "bar") }.to raise_error(RuntimeError)
    end
  end
end
