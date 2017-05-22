# -*- ruby -*-
require 'spec_helper'
require 'packaging/util/git'

# rubocop:disable Metrics/BlockLength
describe 'Pkg::Util::Git' do
  context '#commit_file' do
    let(:file) { 'thing.txt' }
    let(:message) { 'foo' }

    it 'should commit a file with no message, giving changes as the message instead' do
      allow(Pkg::Util::Git).to receive(:fail_unless_repo)
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} diff HEAD #{file}")
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} commit #{file} -m \"Commit changes in #{file}\" &> /dev/null")
      Pkg::Util::Git.commit_file(file)
    end

    it 'should commit a file with foo as message' do
      allow(Pkg::Util::Git).to receive(:fail_unless_repo)
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} diff HEAD #{file}")
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} commit #{file} -m \"Commit #{message} in #{file}\" &> /dev/null")
      Pkg::Util::Git.commit_file(file, message)
    end
  end

  context '#tag' do
    let(:version) { '1.2.3' }
    let(:gpg_key) { '1231242354asdfawd' }
    around do |example|
      prev_gpg_key = Pkg::Config.gpg_key
      Pkg::Config.gpg_key = gpg_key
      example.run
      Pkg::Config.gpg_key = prev_gpg_key
    end

    it 'should not fail' do
      allow(Pkg::Util::Git).to receive(:fail_unless_repo)
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} tag -s -u #{gpg_key} -m '#{version}' #{version}")
      Pkg::Util::Git.tag(version)
    end
  end

  context '#bundle' do
    let(:treeish) { 'foo' }
    let(:appendix) { 'append' }
    let(:output_dir) { '/path/to/place' }
    let(:version) { '1.2.3' }
    let(:project) { 'fooproj' }
    let(:string) { 'bar' }
    let(:temp) { '/other/path/to/place' }
    around do |example|
      prev_project = Pkg::Config.project
      prev_version = Pkg::Config.version
      Pkg::Config.project = project
      Pkg::Config.version = version
      example.run
      Pkg::Config.project = prev_project
      Pkg::Config.version = prev_version
    end

    it 'should create a git bundle with random appendix and random output directory' do
      allow(Pkg::Util::Git).to receive(:fail_unless_repo)
      allow(Pkg::Util::File).to receive(:mktemp) { temp }
      allow(Pkg::Util).to receive(:rand_string) { string }
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} bundle create #{temp}/#{project}-#{version}-#{string} #{treeish} --tags")
      expect(Dir).to receive(:chdir).with(temp)
      Pkg::Util::Git.bundle(treeish)
    end

    it 'should create a git bundle with random output directory' do
      allow(Pkg::Util::Git).to receive(:fail_unless_repo)
      allow(Pkg::Util::File).to receive(:mktemp) { temp }
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} bundle create #{temp}/#{project}-#{version}-#{appendix} #{treeish} --tags")
      expect(Dir).to receive(:chdir).with(temp)
      Pkg::Util::Git.bundle(treeish, appendix)
    end

    it 'should create a git bundle' do
      allow(Pkg::Util::Git).to receive(:fail_unless_repo)
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} bundle create #{output_dir}/#{project}-#{version}-#{appendix} #{treeish} --tags")
      expect(Dir).to receive(:chdir).with(output_dir)
      Pkg::Util::Git.bundle(treeish, appendix, output_dir)
    end
  end

  context '#pull' do
    let(:remote) { 'rand.url' }
    let(:branch) { 'foo' }

    it 'should pull the branch' do
      allow(Pkg::Util::Git).to receive(:fail_unless_repo)
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{Pkg::Util::Tool::GIT} pull #{remote} #{branch}")
      Pkg::Util::Git.pull(remote, branch)
    end
  end

  context '#sha_or_tag' do
    let(:sha) { '20a338b33e2fc1cbaee27b69de5eb2d06637a7c4' }
    let(:tag) { '2.0.4' }

    it 'returns a sha if the repo is not tagged' do
      allow(Pkg::Util::Git).to receive(:ref_type) { 'sha' }
      allow(Pkg::Util::Git).to receive(:sha) { sha }
      expect(Pkg::Util::Git.sha_or_tag).to eq sha
    end

    it 'returns a tag if the repo is tagged' do
      allow(Pkg::Util::Git).to receive(:ref_type) { 'tag' }
      allow(Pkg::Util::Git).to receive(:describe) { tag }
      expect(Pkg::Util::Git.sha_or_tag).to eq tag
    end
  end

  context '#tagged?' do
    let(:sha) { '20a338b33e2fc1cbaee27b69de5eb2d06637a7c4' }
    let(:tag) { '2.0.4' }

    it 'returns false if we are working on a sha' do
      allow(Pkg::Util::Git).to receive(:ref_type) { 'tag' }
      expect(Pkg::Util::Git.tagged?).to be true
    end

    it 'returns true if we are working on a tag' do
      allow(Pkg::Util::Git).to receive(:ref_type) { 'sha' }
      expect(Pkg::Util::Git.tagged?).to be false
    end
  end

  context '#remote_tagged?' do
    it 'reports Yes on tagged component' do
      expect(Pkg::Util::Git.remote_tagged?('git://github.com/puppetlabs/leatherman.git', 'refs/tags/0.6.2')).to be(true)
    end

    it 'reports No on non-tagged component' do
      expect(Pkg::Util::Git.remote_tagged?('git://github.com/puppetlabs/leatherman.git', '4eef05389ebf418b62af17406c7f9f13fa51f975')).to be(false)
    end
  end
end
