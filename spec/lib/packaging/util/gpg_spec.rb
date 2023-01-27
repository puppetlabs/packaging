require 'spec_helper'

describe 'Pkg::Util::Gpg' do
  let(:gpg)      { '/local/bin/gpg' }
  let(:keychain) { '/usr/local/bin/keychain' }
  let(:gpg_key)  { 'abcd1234' }
  let(:target_file) { '/tmp/file' }

  before(:each) do
    reset_env(['RPM_GPG_AGENT'])
    Pkg::Config.gpg_key = gpg_key
  end

  describe '#key' do
    it 'fails if Pkg::Config.gpg_key isn\'t set' do
      allow(Pkg::Config).to receive(:gpg_key).and_return(nil)
      expect { Pkg::Util::Gpg.key }.to raise_error(RuntimeError)
    end
    it 'fails if Pkg::Config.gpg_key is an empty string' do
      allow(Pkg::Config).to receive(:gpg_key).and_return('')
      expect { Pkg::Util::Gpg.key }.to raise_error(RuntimeError)
    end
  end

  describe '#kill_keychain' do
    it 'doesn\'t reload the keychain if already loaded' do
      Pkg::Util::Gpg.instance_variable_set("@keychain_loaded", true)

      expect(Pkg::Util::Gpg).not_to receive(:kill_keychain)
      expect(Pkg::Util::Gpg).not_to receive(:start_keychain)
      Pkg::Util::Gpg.load_keychain
      Pkg::Util::Gpg.instance_variable_set("@keychain_loaded", nil)
    end

    it "doesn't reload the keychain if ENV['RPM_GPG_AGENT'] is set" do
      ENV['RPM_GPG_AGENT'] = 'blerg'
      expect(Pkg::Util::Gpg).not_to receive(:kill_keychain)
      expect(Pkg::Util::Gpg).not_to receive(:start_keychain)
      Pkg::Util::Gpg.load_keychain
    end

    it 'kills and starts the keychain if not loaded already' do
      Pkg::Util::Gpg.instance_variable_set("@keychain_loaded", nil)
      expect(Pkg::Util::Gpg).to receive(:kill_keychain).once
      expect(Pkg::Util::Gpg).to receive(:start_keychain).once
      Pkg::Util::Gpg.load_keychain
    end
  end

  describe '#sign_file' do
    it 'adds special flags if RPM_GPG_AGENT is set' do
      ENV['RPM_GPG_AGENT'] = 'blerg'
      additional_flags = '--no-tty --use-agent'
      expect(Pkg::Util::Tool).to receive(:find_tool).with('gpg').and_return(gpg)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{gpg}\s#{additional_flags}\s--armor --detach-sign -u #{gpg_key} #{target_file}")
      Pkg::Util::Gpg.sign_file(target_file)
    end

    it 'signs without extra flags when RPM_GPG_AGENT is not set' do
      expect(Pkg::Util::Tool).to receive(:find_tool).with('gpg').and_return(gpg)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{gpg}\s\s--armor --detach-sign -u #{gpg_key} #{target_file}")
      Pkg::Util::Gpg.sign_file(target_file)
    end
  end
end
