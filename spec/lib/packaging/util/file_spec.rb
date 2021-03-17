require 'spec_helper'

describe 'Pkg::Util::File' do
  let(:source)     { '/tmp/placething.tar.gz' }
  let(:target)     { '/tmp' }
  let(:options)    { '--thing-for-tar' }
  let(:tar)        { '/usr/bin/tar' }
  let(:files)      { ['foo.rb', 'foo/bar.rb'] }
  let(:symlinks)   { ['bar.rb'] }
  let(:dirs)       { ['foo'] }
  let(:empty_dirs) { ['bar'] }


  describe '#untar_into' do
    before :each do
      allow(Pkg::Util::Tool).to receive(:find_tool).with('tar', :required => true) { tar }
    end

    it 'raises an exception if the source does not exist' do
      expect(Pkg::Util::File).to receive(:file_exists?).with(source, {:required => true}).and_raise(RuntimeError)
      expect(Pkg::Util::Execution).not_to receive(:capture3)
      expect { Pkg::Util::File.untar_into(source) }.to raise_error(RuntimeError)
    end

    it 'unpacks the tarball to the current directory if no target is passed' do
      expect(Pkg::Util::File).to receive(:file_exists?).with(source, {:required => true}) { true }
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{tar}   -xf #{source}")
      Pkg::Util::File.untar_into(source)
    end

    it 'unpacks the tarball to the current directory with options if no target is passed' do
      expect(Pkg::Util::File).to receive(:file_exists?).with(source, {:required => true}) { true }
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{tar} #{options}  -xf #{source}")
      Pkg::Util::File.untar_into(source, nil, options)
    end

    it 'unpacks the tarball into the target' do
      allow(File).to receive(:capture3ist?).with(source).and_return true
      expect(Pkg::Util::File).to receive(:file_exists?).with(source, {:required => true}) { true }
      expect(Pkg::Util::File).to receive(:file_writable?).with(target) { true }
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{tar}  -C #{target} -xf #{source}")
      Pkg::Util::File.untar_into(source, target)
    end

    it 'unpacks the tarball into the target with options passed' do
      allow(File).to receive(:capture3ist?).with(source).and_return true
      expect(Pkg::Util::File).to receive(:file_exists?).with(source, {:required => true}) { true }
      expect(Pkg::Util::File).to receive(:file_writable?).with(target) { true }
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{tar} #{options} -C #{target} -xf #{source}")
      Pkg::Util::File.untar_into(source, target, options)
    end
  end

  describe '#files_with_ext' do
    it 'returns nothing if there are no files with that extension' do
      expect(Pkg::Util::File.files_with_ext('./spec/fixtures/configs/components', '.fake')).to be_empty
    end

    it 'returns only the files with that extension' do
      expect(Pkg::Util::File.files_with_ext('./spec/fixtures/configs/components', '.json')).to include('./spec/fixtures/configs/components/test_file.json')
      expect(Pkg::Util::File.files_with_ext('./spec/fixtures/configs/components', '.json')).to include('./spec/fixtures/configs/components/test_file_2.json')
    end
  end

  describe '#install_files_into_dir' do
    it 'selects the correct files to install' do
      Pkg::Config.load_defaults
      workdir = Pkg::Util::File.mktemp
      patterns = []

      # Set up a bunch of default settings for these to avoid a lot more stubbing in each section below
      allow(File).to receive(:file?).and_return false
      allow(File).to receive(:symlink?).and_return false
      allow(File).to receive(:directory?).and_return false
      allow(Pkg::Util::File).to receive(:empty_dir?).and_return false

      # Files should have the path made and should be copied
      files.each do |file|
        allow(File).to receive(:file?).with(file).and_return true
        allow(Dir).to receive(:[]).with(file).and_return(file)
        expect(FileUtils).to receive(:mkpath).with(File.dirname(File.join(workdir, file)), :verbose => false)
        expect(FileUtils).to receive(:cp).with(file, File.join(workdir, file), :verbose => false, :preserve => true)
        patterns << file
      end

      # Symlinks should have the path made and should be copied
      symlinks.each do |file|
        allow(File).to receive(:symlink?).with(file).and_return(true)
        allow(Dir).to receive(:[]).with(file).and_return(file)
        expect(FileUtils).to receive(:mkpath).with(File.dirname(File.join(workdir, file)), :verbose => false)
        expect(FileUtils).to receive(:cp).with(file, File.join(workdir, file), :verbose => false, :preserve => true)
        patterns << file
      end

      # Dirs should be added to patterns but no acted upon
      dirs.each do |dir|
        allow(File).to receive(:directory?).with(dir).and_return(true)
        allow(Dir).to receive(:[]).with("#{dir}/**/*").and_return(dir)
        expect(FileUtils).not_to receive(:mkpath)
                                   .with(File.dirname(File.join(workdir, dir)), :verbose => false)
        expect(FileUtils).not_to receive(:cp)
                                   .with(dir, File.join(workdir, dir), :verbose => false, :preserve => true)
        patterns << dir
      end

      # Empty dirs should have the path created and nothing copied
      empty_dirs.each do |dir|
        allow(Pkg::Util::File).to receive(:empty_dir?).with(dir).and_return(true)
        allow(Dir).to receive(:[]).with(dir).and_return(dir)
        expect(FileUtils).to receive(:mkpath).with(File.join(workdir, dir), :verbose => false)
        expect(FileUtils).not_to receive(:cp).with(dir, File.join(workdir, dir), :verbose => false, :preserve => true)
        patterns << dir
      end

      Pkg::Util::File.install_files_into_dir(patterns, workdir)
      FileUtils.rm_rf workdir
    end
  end

  describe '#directories' do
    it 'returns nil if there is no directory' do
      expect(File).to receive(:directory?).with('/tmp').and_return(false)
      expect(Pkg::Util::File.directories('/tmp')).to be_nil
    end

    it 'returns the empty array if there are no dirs in the directory' do
      expect(File).to receive(:directory?).with('/tmp').and_return(true)
      expect(Dir).to receive(:glob).with('*').and_return([])
      expect(Pkg::Util::File.directories('/tmp')).to be_empty
    end

    it 'returns an array of the top level directories inside a directory' do
      allow(File).to receive(:directory?).and_return false
      ['/tmp', '/tmp/dir', '/tmp/other_dir'].each do |dir|
        expect(File).to receive(:directory?).with(dir).and_return(true)
      end
      expect(Dir).to receive(:glob).with('*').and_return(['/tmp/file', '/tmp/dir', '/tmp/other_dir'])
      expect(Pkg::Util::File.directories('/tmp')).to eq(['/tmp/dir', '/tmp/other_dir'])
    end
  end
end
