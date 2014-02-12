require 'spec_helper'

describe "Pkg::Util::File" do
  let(:source)  { "/tmp/placething.tar.gz" }
  let(:target)  { "/tmp" }
  let(:options) { "--thing-for-tar" }
  let(:tar)     { "/usr/bin/tar" }

  describe "#untar_into" do
    before :each do
      Pkg::Util::Tool.stub(:find_tool).with('tar', :required => true) { tar }
    end

    it "raises an exception if the source doesn't exist" do
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}).and_raise(RuntimeError)
      Pkg::Util::File.should_not_receive(:ex)
      expect { Pkg::Util::File.untar_into(source) }.to raise_error(RuntimeError)
    end

    it "unpacks the tarball to the current directory if no target is passed" do
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}) { true }
      Pkg::Util::File.should_receive(:ex).with("#{tar}   -xf #{source}")
      Pkg::Util::File.untar_into(source)
    end

    it "unpacks the tarball to the current directory with options if no target is passed" do
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}) { true }
      Pkg::Util::File.should_receive(:ex).with("#{tar} #{options}  -xf #{source}")
      Pkg::Util::File.untar_into(source, nil, options)
    end

    it "unpacks the tarball into the target" do
      File.stub(:exist?).with(source) { true }
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}) { true }
      Pkg::Util::File.should_receive(:file_writable?).with(target) { true }
      Pkg::Util::File.should_receive(:ex).with("#{tar}  -C #{target} -xf #{source}")
      Pkg::Util::File.untar_into(source, target)
    end

    it "unpacks the tarball into the target with options passed" do
      File.stub(:exist?).with(source) { true }
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}) { true }
      Pkg::Util::File.should_receive(:file_writable?).with(target) { true }
      Pkg::Util::File.should_receive(:ex).with("#{tar} #{options} -C #{target} -xf #{source}")
      Pkg::Util::File.untar_into(source, target, options)
    end
  end
end
