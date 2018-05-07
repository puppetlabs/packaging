# -*- ruby -*-
require 'spec_helper'

describe "tar.rb" do
  let(:project) { "packaging" }
  let(:version) { "1.2.3" }
  let(:files)   { [ "a", "b", "c" ] }
  let(:templates) do
    [
      "ext/redhat/spec.erb",
      { "source" => "ext/debian/control.erb", "target" => "ext/debian/not-a-control-file" },
      "ext/debian/changelog.erb",
      "ext/packaging/thing.erb"
    ]
  end
  let(:expanded_templates) do
    [
      "#{PROJECT_ROOT}/ext/redhat/spec.erb",
      { "source" => "ext/debian/control.erb", "target" => "ext/debian/not-a-control-file" },
      "#{PROJECT_ROOT}/ext/debian/changelog.erb"
    ]
  end
  before(:each) do
    Pkg::Config.config_from_hash(
      {
        :templates      => templates,
        :project        => project,
        :version        => version,
        :files          => files,
        :project_root   => PROJECT_ROOT,
        :packaging_root => "ext/packaging"
      })
  end

  describe '#initialize' do
    it 'should always mark ext/packaging and pkg directories as excluded files' do
      Pkg::Config.tar_excludes = ['foo']
      expect(Pkg::Tar.new.excludes).to eql(['foo', 'pkg', 'ext/packaging'])

      Pkg::Config.tar_excludes = []
      expect(Pkg::Tar.new.excludes).to eql(['pkg', 'ext/packaging'])
    end
  end

  describe "#expand_templates" do
    it "should be invoked when Pkg::Config.templates is set" do
      Pkg::Tar.any_instance.should_receive(:expand_templates)
      Pkg::Tar.new
    end

    it "packaging templates should be filtered and paths should be expanded" do
      templates.each do |temp|
        if temp.is_a?(String)
          Dir.stub(:glob).with(File.join(PROJECT_ROOT, temp)).and_return(File.join(PROJECT_ROOT, temp))
        end
      end

      tar = Pkg::Tar.new
      tar.templates = templates
      tar.expand_templates
      tar.templates.should eq expanded_templates
    end
  end

  describe "#template" do
    before(:each) do
      Pkg::Config.templates = expanded_templates
    end

    it "should handle hashes and strings correctly" do
      # Set up correct stubs and expectations
      expanded_templates.each do |temp|
        if temp.is_a?(String)
          full_path_temp = File.join(PROJECT_ROOT, temp)
          target = full_path_temp.sub(File.extname(full_path_temp), "")
        elsif temp.is_a?(Hash)
          full_path_temp = File.join(PROJECT_ROOT, temp["source"])
          target = File.join(PROJECT_ROOT, temp["target"])
        end

        Dir.stub(:glob).with(full_path_temp).and_return(full_path_temp)
        File.stub(:exist?).with(full_path_temp).and_return(true)
        Pkg::Util::File.should_receive(:erb_file).with(full_path_temp, target, true, :binding => an_instance_of(Binding))
      end

      Pkg::Tar.new.template
    end

    it "should raise an error if the template source can't be found" do
      # Set up correct stubs and expectations
      expanded_templates.each do |temp|
        if temp.is_a?(String)
          full_path_temp = File.join(PROJECT_ROOT, temp)
          target = full_path_temp.sub(File.extname(full_path_temp), "")
        elsif temp.is_a?(Hash)
          full_path_temp = File.join(PROJECT_ROOT, temp["source"])
          target = File.join(PROJECT_ROOT, temp["target"])
        end

        Dir.stub(:glob).with(full_path_temp).and_return(full_path_temp)
        File.stub(:exist?).with(full_path_temp).and_return(false)
      end

      expect { Pkg::Tar.new.template }.to raise_error RuntimeError
    end
  end
end
