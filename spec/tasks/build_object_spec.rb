# -*- ruby -*-
require 'spec_helper'
load_task '00_utils.rake'
load_task 'build.rake'

describe Build::BuildInstance do
  Build_Params = [:apt_host,
                  :apt_repo_path,
                  :apt_repo_url,
                  :author,
                  :benchmark,
                  :build_defaults,
                  :build_dmg,
                  :build_doc,
                  :build_gem,
                  :build_ips,
                  :build_pe,
                  :builder_data_file,
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
                  :gem_excludes,
                  :gem_executables,
                  :gem_files,
                  :gem_forge_project,
                  :gem_name,
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
                  :name,
                  :project,
                  :origversion,
                  :osx_build_host,
                  :packager,
                  :packaging_repo,
                  :packaging_url,
                  :pbuild_conf,
                  :pe_name,
                  :pe_version,
                  :pg_major_version,
                  :privatekey_pem,
                  :rc_mocks,
                  :release,
                  :rpm_build_host,
                  :rpmrelease,
                  :rpmversion,
                  :sha,
                  :sign_tar,
                  :sles_build_host,
                  :sles_repo_path,
                  :sles_repo_host,
                  :sles_arch_repos,
                  :summary,
                  :tar_excludes,
                  :tarball_path,
                  :team,
                  :version,
                  :version_file,
                  :yum_host,
                  :yum_repo_path]

  before :each do
    @build = Build::BuildInstance.new
  end

  describe "#new" do
    Build_Params.each do |param|
      it "should have r/w accessors for #{param}" do
        @build.should respond_to(param)
        @build.should respond_to("#{param.to_s}=")
      end
    end
  end

  describe "#set_params_from_hash" do
    good_params = { :yum_host => 'foo', :pe_name => 'bar' }
    context "given a valid params hash #{good_params}" do
      it "should set instance variable values for each param" do
        good_params.each do |param, value|
          @build.should_receive(:instance_variable_set).with("@#{param}", value)
        end
        @build.set_params_from_hash(good_params)
      end
    end

    bad_params = { :foo => 'bar' }
    context "given an invalid params hash #{bad_params}" do
      bad_params.each do |param, value|
        it "should print a warning that param '#{param}' is not valid" do
          @build.should_receive(:warn).with(/No build data parameter found for '#{param}'/)
          @build.set_params_from_hash(bad_params)
        end

        it "should not try to set instance variable @:#{param}" do
          @build.should_not_receive(:instance_variable_set).with("@#{param}", value)
          @build.set_params_from_hash(bad_params)
        end
      end
    end

    mixed_params = { :sign_tar => TRUE, :baz => 'qux' }
    context "given a hash with both valid and invalid params" do
      it "should set the valid param" do
        @build.should_receive(:instance_variable_set).with("@sign_tar", TRUE)
        @build.set_params_from_hash(mixed_params)
      end

      it "should issue a warning that the invalid param is not valid" do
        @build.should_receive(:warn).with(/No build data parameter found for 'baz'/)
        @build.set_params_from_hash(mixed_params)
      end

      it "should not try to set instance variable @:baz" do
        @build.should_not_receive(:instance_variable_set).with("@baz", "qux")
        @build.set_params_from_hash(mixed_params)
      end
    end
  end

  describe "#params" do
    it "should return a hash containing keys for all build parameters" do
      params = @build.params
      Build_Params.each { |param| params.has_key?(param).should == TRUE }
    end
  end

  describe "#params_to_yaml" do
    it "should write a valid yaml file" do
      file = mock('file')
      File.should_receive(:open).with(anything(), 'w').and_yield(file)
      file.should_receive(:puts).with(instance_of(String))
      YAML.should_receive(:load_file).with(file)
      expect { YAML.load_file(file) }.to_not raise_error
      @build.params_to_yaml
    end
  end
end
