require 'spec_helper'

describe "Pkg::Util::Gpg" do
  let(:gpg)      { "/local/bin/gpg" }
  let(:keychain) { "/usr/local/bin/keychain" }
  let(:gpg_key)  { "abcd1234" }
  let(:target_file) { "/tmp/file" }

  before(:each) do
    reset_env(['RPM_GPG_AGENT'])
    Pkg::Config.gpg_key = gpg_key
  end

  describe '#kill_keychain' do
    it "doesn't reload the keychain if already loaded" do
      Pkg::Util::Gpg.instance_variable_set("@keychain_loaded", TRUE)
      Pkg::Util::Gpg.should_receive(:kill_keychain).never
      Pkg::Util::Gpg.should_receive(:start_keychain).never
      Pkg::Util::Gpg.load_keychain
      Pkg::Util::Gpg.instance_variable_set("@keychain_loaded", nil)
    end

    it "doesn't reload the keychain if ENV['RPM_GPG_AGENT'] is set" do
      ENV['RPM_GPG_AGENT'] = 'blerg'
      Pkg::Util::Gpg.should_receive(:kill_keychain).never
      Pkg::Util::Gpg.should_receive(:start_keychain).never
      Pkg::Util::Gpg.load_keychain
    end

    it 'kills and starts the keychain if not loaded already' do
      Pkg::Util::Gpg.instance_variable_set("@keychain_loaded", nil)
      Pkg::Util::Gpg.should_receive(:kill_keychain).once
      Pkg::Util::Gpg.should_receive(:start_keychain).once
      Pkg::Util::Gpg.load_keychain
    end
  end

  describe '#sign_file' do
    it 'adds special flags if RPM_GPG_AGENT is set' do
      ENV['RPM_GPG_AGENT'] = 'blerg'
      additional_flags = "--no-tty --use-agent"
      Pkg::Util::Tool.should_receive(:find_tool).with('gpg').and_return(gpg)
      Pkg::Util::Execution.should_receive(:capture3).with("#{gpg}\s#{additional_flags}\s--armor --detach-sign -u #{gpg_key} #{target_file}")
      Pkg::Util::Gpg.sign_file(target_file)
    end

    it 'signs without extra flags when RPM_GPG_AGENT is not set' do
      Pkg::Util::Tool.should_receive(:find_tool).with('gpg').and_return(gpg)
      Pkg::Util::Execution.should_receive(:capture3).with("#{gpg}\s\s--armor --detach-sign -u #{gpg_key} #{target_file}")
      Pkg::Util::Gpg.sign_file(target_file)
    end
  end
end
