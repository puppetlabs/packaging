# -*- ruby -*-
require 'spec_helper'
require 'yaml'

describe "Pkg::Config" do

  Build_Params = [:apt_host,
                  :apt_repo_path,
                  :apt_repo_url,
                  :author,
                  :benchmark,
                  :build_date,
                  :build_defaults,
                  :build_dmg,
                  :build_doc,
                  :build_gem,
                  :build_ips,
                  :build_pe,
                  :builder_data_file,
                  :bundle_platforms,
                  :certificate_pem,
                  :cows,
                  :db_table,
                  :deb_build_host,
                  :debversion,
                  :debug,
                  :default_cow,
                  :default_mock,
                  :description,
                  :dmg_path,
                  :email,
                  :files,
                  :final_mocks,
                  :freight_conf,
                  :gem_default_executables,
                  :gem_dependencies,
                  :gem_description,
                  :gem_devel_dependencies,
                  :gem_development_dependencies,
                  :gem_excludes,
                  :gem_executables,
                  :gem_files,
                  :gem_forge_project,
                  :gem_name,
                  :gem_platform_dependencies,
                  :gem_rdoc_options,
                  :gem_require_path,
                  :gem_runtime_dependencies,
                  :gem_summary,
                  :gem_test_files,
                  :gemversion,
                  :gpg_key,
                  :gpg_name,
                  :homepage,
                  :ips_build_host,
                  :ips_host,
                  :ips_inter_cert,
                  :ips_package_host,
                  :ips_path,
                  :ips_repo,
                  :ips_store,
                  :ipsversion,
                  :jenkins_build_host,
                  :jenkins_packaging_job,
                  :jenkins_repo_path,
                  :metrics,
                  :metrics_url,
                  :name,
                  :notify,
                  :project,
                  :origversion,
                  :osx_build_host,
                  :packager,
                  :packaging_repo,
                  :packaging_root,
                  :packaging_url,
                  :pbuild_conf,
                  :pe_name,
                  :pe_version,
                  :pg_major_version,
                  :pre_tar_task,
                  :pre_tasks,
                  :privatekey_pem,
                  :random_mockroot,
                  :rc_mocks,
                  :release,
                  :rpm_build_host,
                  :rpmrelease,
                  :rpmversion,
                  :ref,
                  :sign_tar,
                  :summary,
                  :tar_excludes,
                  :tar_host,
                  :tarball_path,
                  :team,
                  :templates,
                  :update_version_file,
                  :version,
                  :version_file,
                  :version_strategy,
                  :yum_host,
                  :yum_repo_path]

  describe "#new" do
    Build_Params.each do |param|
      it "should have r/w accessors for #{param}" do
        Pkg::Config.should respond_to(param)
        Pkg::Config.should respond_to("#{param.to_s}=")
      end
    end
  end

  describe "#config_from_hash" do
    good_params = { :yum_host => 'foo', :pe_name => 'bar' }
    context "given a valid params hash #{good_params}" do
      it "should set instance variable values for each param" do
        good_params.each do |param, value|
          Pkg::Config.should_receive(:instance_variable_set).with("@#{param}", value)
        end
        Pkg::Config.config_from_hash(good_params)
      end
    end

    bad_params = { :foo => 'bar' }
    context "given an invalid params hash #{bad_params}" do
      bad_params.each do |param, value|
        it "should print a warning that param '#{param}' is not valid" do
          Pkg::Config.should_receive(:warn).with(/No build data parameter found for '#{param}'/)
          Pkg::Config.config_from_hash(bad_params)
        end

        it "should not try to set instance variable @:#{param}" do
          Pkg::Config.should_not_receive(:instance_variable_set).with("@#{param}", value)
          Pkg::Config.config_from_hash(bad_params)
        end
      end
    end

    mixed_params = { :sign_tar => TRUE, :baz => 'qux' }
    context "given a hash with both valid and invalid params" do
      it "should set the valid param" do
        Pkg::Config.should_receive(:instance_variable_set).with("@sign_tar", TRUE)
        Pkg::Config.config_from_hash(mixed_params)
      end

      it "should issue a warning that the invalid param is not valid" do
        Pkg::Config.should_receive(:warn).with(/No build data parameter found for 'baz'/)
        Pkg::Config.config_from_hash(mixed_params)
      end

      it "should not try to set instance variable @:baz" do
        Pkg::Config.should_not_receive(:instance_variable_set).with("@baz", "qux")
        Pkg::Config.config_from_hash(mixed_params)
      end
    end
  end

  describe "#params" do
    it "should return a hash containing keys for all build parameters" do
      params = Pkg::Config.config
      Build_Params.each { |param| params.has_key?(param).should == TRUE }
    end
  end

  describe "#config_to_yaml" do
    it "should write a valid yaml file" do
      file = double('file')
      File.should_receive(:open).with(anything(), 'w').and_yield(file)
      file.should_receive(:puts).with(instance_of(String))
      YAML.should_receive(:load_file).with(file)
      expect { YAML.load_file(file) }.to_not raise_error
      Pkg::Config.config_to_yaml
    end
  end

  describe "#get_binding" do
    it "should return the binding of the Pkg::Config object" do
      # test by eval'ing using the binding before and after setting a param
      orig = Pkg::Config.apt_host
      Pkg::Config.apt_host = "foo"
      expect(eval("@apt_host", Pkg::Config.get_binding)).to eq("foo")
      Pkg::Config.apt_host = "bar"
      expect(eval("@apt_host", Pkg::Config.get_binding)).to eq("bar")
      Pkg::Config.apt_host = orig
    end
  end

  describe "#config_from_yaml" do
    context "given a yaml file" do
      it "should, use it to set params" do
        # apt_host: is set to "foo" in the fixture
        orig = Pkg::Config.apt_host
        Pkg::Config.apt_host = "bar"
        Pkg::Config.config_from_yaml(File.join(FIXTURES, 'config', 'params.yaml'))
        expect(Pkg::Config.apt_host).to eq("foo")
        Pkg::Config.apt_host = orig
      end
    end
  end

  describe "#config" do
    context "given :format => :hash" do
      it "should call Pkg::Config.config_to_hash" do
        expect(Pkg::Config).to receive(:config_to_hash)
        Pkg::Config.config(:target => nil, :format => :hash)
      end
    end

    context "given :format => :yaml" do
      it "should call Pkg::Config.config_to_yaml if given :format => :yaml" do
        expect(Pkg::Config).to receive(:config_to_yaml)
        Pkg::Config.config(:target => nil, :format => :yaml)
      end
    end
  end

  describe "#issue_reassignments" do
    before :all do
      prev_tar_host = Pkg::Config.tar_host
      Pkg::Config.tar_host = nil
    end

    it "should set tar_host to yum_host" do
      Pkg::Config.config_from_hash({ :yum_host => 'foo' })
      Pkg::Config.issue_reassignments
      Pkg::Config.tar_host.should eq("foo")
    end

    after :all do
      Pkg::Config.tar_host = prev_tar_host
    end
  end

  describe "#config_to_hash" do
    it "should return a hash object" do
      hash = Pkg::Config.config_to_hash
      hash.should be_a(Hash)
    end

    it "should return a hash with the current parameters" do
      Pkg::Config.apt_host = "foo"
      Pkg::Config.config_to_hash[:apt_host].should eq("foo")
      Pkg::Config.apt_host = "bar"
      Pkg::Config.config_to_hash[:apt_host].should eq("bar")
    end
  end

  describe "#load_default_configs" do
    context "given ext/build_defaults.yaml and ext/project_data.yaml are readable" do
      it "should try to load build_defaults.yaml and project_data.yaml" do
        orig = Pkg::Config.project_root
        Pkg::Config.project_root = File.join(FIXTURES, 'config')
        test_project_data = File.join(FIXTURES, 'config', 'ext', 'project_data.yaml')
        test_build_defaults = File.join(FIXTURES, 'config', 'ext', 'build_defaults.yaml')
        expect(Pkg::Config).to receive(:config_from_yaml).with(test_project_data)
        expect(Pkg::Config).to receive(:config_from_yaml).with(test_build_defaults)
        Pkg::Config.load_default_configs
        Pkg::Config.project_root = orig
      end
    end

    context "given ext/build_defaults.yaml and ext/project_data.yaml are not readable" do
      it "should not try to load build_defaults.yaml and project_data.yaml" do
        orig = Pkg::Config.project_root
        Pkg::Config.project_root = 'foo'
        expect(Pkg::Config).to_not receive(:config_from_yaml)
        Pkg::Config.load_default_configs
        Pkg::Config.project_root = orig
      end

      it "should set the project root to nil" do
        orig = Pkg::Config.project_root
        Pkg::Config.project_root = 'foo'
        Pkg::Config.load_default_configs
        expect(Pkg::Config.project_root).to be(nil)
        Pkg::Config.project_root = orig
      end
    end
  end

  describe "#load_versioning" do
      # We let the actual version determination testing happen in the version
      # tests. Here we just test that we try when we should.
    context "When project root is nil" do
      it "should not try to load versioning" do
        Pkg::Config.stub(:project_root) {nil}
        expect(Pkg::Config).to_not receive(:git_sha_or_tag)
      end
    end
  end

  describe "#load_envvars" do
    # We're going to pollute the environment with this test, so afterwards we
    # explicitly set everything to nil to prevent any hazardous effects on
    # the rest of the tests.
    after(:all) do
      Pkg::Params::ENV_VARS.each do |v|
        ENV[v[:envvar].to_s] = nil
      end
    end

    Pkg::Params::ENV_VARS.each do |v|
      ENV[v[:envvar].to_s] = "FOO"
      if v[:type] == :bool
        it "should set boolean value on #{v[:var]} for :type == :bool" do
          Pkg::Util.stub(:boolean_value) {"FOO"}
          allow(Pkg::Config).to receive(:instance_variable_set)
          expect(Pkg::Util).to receive(:boolean_value).with("FOO")
          expect(Pkg::Config).to receive(:instance_variable_set).with("@#{v[:var]}", "FOO")
          Pkg::Config.load_envvars
        end
      else
        it "should set Pkg::Config##{v[:var]} to ENV[#{v[:envvar].to_s}]" do
          Pkg::Util.stub(:boolean_value) {"FOO"}
          allow(Pkg::Config).to receive(:instance_variable_set)
          expect(Pkg::Config).to receive(:instance_variable_set).with("@#{v[:var]}", "FOO")
          Pkg::Config.load_envvars
        end
      end
    end
  end
end
