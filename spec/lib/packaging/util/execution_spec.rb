require 'spec_helper'

describe 'Pkg::Util::Execution' do
  let(:command)    { '/usr/bin/do-something-important --arg1=thing2' }
  let(:output)     { 'the command returns some really cool stuff that may be useful later' }

  describe '#success?' do
    it 'should return false on failure' do
      %x{false}
      expect(Pkg::Util::Execution.success?).to be false
    end

    it 'should return true on success' do
      %x{true}
      expect(Pkg::Util::Execution.success?).to be true
    end

    it 'should return false when passed an exitstatus object from a failure' do
      %x{false}
      expect(Pkg::Util::Execution.success?($?)).to be false
    end

    it 'should return true when passed and exitstatus object from a success' do
      %x{true}
      expect(Pkg::Util::Execution.success?($?)).to be true
    end
  end

  describe '#ex' do
    it 'should raise an error if the command fails' do
      expect(Pkg::Util::Execution).to receive(:`).with(command).and_return(true)
      expect(Pkg::Util::Execution).to receive(:success?).and_return(false)
      expect{ Pkg::Util::Execution.ex(command) }.to raise_error(RuntimeError)
    end

    it 'should return the output of the command for success' do
      expect(Pkg::Util::Execution).to receive(:`).with(command).and_return(output)
      expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
      expect(Pkg::Util::Execution.ex(command)).to be output
    end
  end

  describe '#capture3' do
    it 'should raise an error if the command fails' do
      expect(Open3).to receive(:capture3).with(command).and_return([output, '', 1])
      expect(Pkg::Util::Execution).to receive(:success?).with(1).and_return(false)
      expect{ Pkg::Util::Execution.capture3(command) }.to raise_error(RuntimeError, /#{output}/)
    end

    it 'should return the output of the command for success' do
      expect(Open3).to receive(:capture3).with(command).and_return([output, '', 0])
      expect(Pkg::Util::Execution).to receive(:success?).with(0).and_return(true)
      expect(Pkg::Util::Execution.capture3(command)).to eq [output, '', 0]
    end
  end
end
