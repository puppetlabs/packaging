require 'spec_helper'

describe "Pkg::Util::Execution" do
  let(:command)    { "/usr/bin/do-something-important --arg1=thing2" }
  let(:output)     { "the command returns some really cool stuff that may be useful later" }

  describe "#success?" do
    it "should return false on failure" do
      %x{false}
      Pkg::Util::Execution.success?.should be_false
    end

    it "should return true on success" do
      %x{true}
      Pkg::Util::Execution.success?.should be_true
    end

    it "should return false when passed an exitstatus object from a failure" do
      %x{false}
      Pkg::Util::Execution.success?($?).should be_false
    end

    it "should return true when passed and exitstatus object from a success" do
      %x{true}
      Pkg::Util::Execution.success?($?).should be_true
    end
  end

  describe "#ex" do
    it "should raise an error if the command fails" do
      Pkg::Util::Execution.should_receive(:`).with("#{command} 2>&1").and_return(true)
      Pkg::Util::Execution.should_receive(:success?).and_return(false)
      expect{ Pkg::Util::Execution.ex(command) }.to raise_error(RuntimeError)
    end

    it "should return the output of the command for success" do
      Pkg::Util::Execution.should_receive(:`).with("#{command} 2>&1").and_return(output)
      Pkg::Util::Execution.should_receive(:success?).and_return(true)
      Pkg::Util::Execution.ex(command).should == output
    end
  end
end
