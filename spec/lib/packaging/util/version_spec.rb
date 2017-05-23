# -*- ruby -*-
require 'spec_helper'

# Spec tests for Pkg::Util::Version
#
# rubocop:disable Metrics/BlockLength
describe 'Pkg::Util::Version' do
  context '#versionbump' do
    let(:version_file) { 'thing.txt' }
    let(:version) { '1.2.3' }
    let(:orig_contents) { "abcd\nVERSION = @DEVELOPMENT_VERSION@\n" }
    let(:updated_contents) { "abcd\nVERSION = #{version}\n" }

    it 'should update the version file contents accordingly' do
      Pkg::Config.config_from_hash(project: 'foo', version_file: version_file)
      allow(IO).to receive(:read).with(version_file) { orig_contents }
      allow(Pkg::Config).to receive(:version) { version }
      version_file_to_write = double('file')
      expect(File).to receive(:open).with(version_file, 'w').and_yield(version_file_to_write)
      expect(version_file_to_write).to receive(:write).with(updated_contents)
      Pkg::Util::Version.versionbump
    end
  end

  describe '#base_pkg_version' do
    version_hash = {
      '5.6' => ['5.6', '1'],
      '1.0.0' => ['1.0.0', '1'],
      '2017.6.5.3' => ['2017.6.5.3', '1'],
      '4.99.0-22' => ['4.99.0.22', '0.1'],
      '1.0.0-658-gabc1234' => ['1.0.0.658.gabc1234', '0.1'],
      '5.0.0.master.SNAPSHOT.2017.05.16T1357' => ['5.0.0.master', '0.1SNAPSHOT.2017.05.16T1357'],
      '5.9.7-rc4' => ['5.9.7', '0.1rc4'],
      '5.9.7-rc4-65-gabc1234' => ['5.9.7.65.gabc1234', '0.1rc4'],
      '5.9.7-rc4-65-gabc1234-dirty' => ['5.9.7.65.gabc1234', '0.1rc4dirty'],
      '4.99.0-dirty' => ['4.99.0', '0.1dirty'],
      '4.99.0-56-gabc1234-dirty' => ['4.99.0.56.gabc1234', '0.1dirty']
    }
    version_hash.each do |pre, post|
      before do
        allow(Pkg::Config).to receive(:version) { pre }
        allow(Pkg::Config).to receive(:release) { '1' }
        allow(Pkg::Config).to receive(:vanagon_project) { false }
      end

      it "transforms #{pre} to #{post}" do
        expect(Pkg::Util::Version.base_pkg_version(pre)).to eq post
      end
    end
  end

  describe '#final?' do
    final_versions = [
      '1.0.0',
      '2017.6.5.3',
      '0.6.8',
      '2068.532.6',
      '96.5'
    ]

    non_final_versions = [
      '4.99.0-22',
      '1.0.0-658-gabc1234',
      '5.0.0.master.SNAPSHOT.2017.05.16T1357',
      '5.9.7-rc4',
      '4.99.0-56-dirty'
    ]

    final_versions.each do |version|
      it "returns true when given #{version}" do
        allow(Pkg::Config).to receive(:version) { nil }
        expect(Pkg::Util::Version.final?(version)).to be true
      end
    end

    non_final_versions.each do |version|
      it "returns false when given #{version}" do
        allow(Pkg::Config).to receive(:version) { nil }
        expect(Pkg::Util::Version.final?(version)).to be false
      end
    end

    it 'correctly reads a final version from Pkg::Config.version' do
      allow(Pkg::Config).to receive(:version) { '1.0.0' }
      expect(Pkg::Util::Version.final?).to be true
    end

    it 'correctly reads a non-final version from Pkg::Config.version' do
      allow(Pkg::Config).to receive(:version) { '4.99.0-56-dirty' }
      expect(Pkg::Util::Version.final?).to be false
    end
  end
end
