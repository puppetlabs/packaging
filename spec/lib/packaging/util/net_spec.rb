require 'spec_helper'
require 'socket'

describe "Pkg::Util::Net" do
  let(:target)     { "/tmp/placething" }
  let(:target_uri) { "http://google.com" }
  let(:content)    { "stuff" }
  let(:rsync)      { "/bin/rsync" }
  let(:ssh)        { "/usr/local/bin/ssh" }

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
      Pkg::Util::Tool.stub(:find_tool).with("ssh") { fail }
      Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_raise(RuntimeError)
      expect{ Pkg::Util::Net.remote_ssh_cmd("foo", "bar") }.to raise_error(RuntimeError)
    end

    it "should execute a command :foo on a host :bar" do
      Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
      Kernel.should_receive(:system).with("#{ssh} -t foo 'bar'")
      Pkg::Util::Execution.should_receive(:success?).and_return(true)
      Pkg::Util::Net.remote_ssh_cmd("foo", "bar")
    end

    it "should escape single quotes in the command" do
      Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
      Kernel.should_receive(:system).with("#{ssh} -t foo 'b'\\''ar'")
      Pkg::Util::Execution.should_receive(:success?).and_return(true)
      Pkg::Util::Net.remote_ssh_cmd("foo", "b'ar")
    end

    it "should raise an error if ssh fails" do
      Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
      Kernel.should_receive(:system).with("#{ssh} -t foo 'bar'")
      Pkg::Util::Execution.should_receive(:success?).and_return(false)
      expect{ Pkg::Util::Net.remote_ssh_cmd("foo", "bar") }.to raise_error(RuntimeError, /Remote ssh command failed./)
    end
  end

  describe "#rsync_to" do
    it "should fail if rsync is not present" do
      Pkg::Util::Tool.stub(:find_tool).with("rsync") { fail }
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_raise(RuntimeError)
      expect{ Pkg::Util::Net.rsync_to("foo", "bar", "boo") }.to raise_error(RuntimeError)
    end

    it "should rsync 'thing' to 'foo@bar:/home/foo' with flags '-rHlv -O --no-perms --no-owner --no-group --ignore-existing'" do
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_return(rsync)
      Pkg::Util::Execution.should_receive(:ex).with("#{rsync} -rHlv -O --no-perms --no-owner --no-group --ignore-existing thing foo@bar:/home/foo")
      Pkg::Util::Net.rsync_to("thing", "foo@bar", "/home/foo")
    end
  end

  describe "#rsync_from" do
    it "should fail if rsync is not present" do
      Pkg::Util::Tool.stub(:find_tool).with("rsync") { fail }
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_raise(RuntimeError)
      expect{ Pkg::Util::Net.rsync_from("foo", "bar", "boo") }.to raise_error(RuntimeError)
    end

    it "should rsync 'thing' from 'foo@bar' to '/home/foo' with flags '-rHlv -O --no-perms --no-owner --no-group'" do
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_return(rsync)
      Pkg::Util::Execution.should_receive(:ex).with("#{rsync} -rHlv -O --no-perms --no-owner --no-group foo@bar:thing /home/foo")
      Pkg::Util::Net.rsync_from("thing", "foo@bar", "/home/foo")
    end
  end
end
