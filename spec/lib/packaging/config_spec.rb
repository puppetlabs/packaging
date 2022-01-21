# -*- ruby -*-
require 'spec_helper'
require 'yaml'

describe "Pkg::Config" do

  Build_Params = [:apt_archive_path,
                  :apt_archive_repo_command,
                  :apt_host,
                  :apt_releases,
                  :apt_repo_path,
                  :apt_repo_url,
                  :apt_repo_name,
                  :apt_repo_command,
                  :author,
                  :benchmark,
                  :build_date,
                  :build_defaults,
                  :build_dmg,
                  :build_doc,
                  :build_gem,
                  :build_ips,
                  :build_msi,
                  :build_pe,
                  :build_tar,
                  :builder_data_file,
                  :bundle_platforms,
                  :certificate_pem,
                  :cows,
                  :db_table,
                  :deb_build_host,
                  :deb_build_mirrors,
                  :debversion,
                  :debug,
                  :default_cow,
                  :default_mock,
                  :description,
                  :dmg_path,
                  :downloads_archive_path,
                  :email,
                  :files,
                  :final_mocks,
                  :freight_archive_path,
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
                  :gem_host,
                  :gem_license,
                  :gem_name,
                  :gem_path,
                  :gem_platform_dependencies,
                  :gem_rdoc_options,
                  :gem_require_path,
                  :gem_required_ruby_version,
                  :gem_required_rubygems_version,
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
                  :jenkins_build_host,
                  :jenkins_packaging_job,
                  :jenkins_repo_path,
                  :metrics,
                  :metrics_url,
                  :msi_name,
                  :name,
                  :nonfinal_apt_repo_command,
                  :nonfinal_apt_repo_path,
                  :nonfinal_apt_repo_staging_path,
                  :nonfinal_dmg_path,
                  :nonfinal_gem_path,
                  :nonfinal_ips_path,
                  :nonfinal_msi_path,
                  :nonfinal_p5p_path,
                  :nonfinal_repo_name,
                  :nonfinal_repo_link_target,
                  :nonfinal_svr4_path,
                  :nonfinal_swix_path,
                  :nonfinal_yum_repo_path,
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
                  :repo_name,
                  :short_ref,
                  :sign_tar,
                  :signing_server,
                  :summary,
                  :svr4_host,
                  :svr4_path,
                  :swix_path,
                  :tar_excludes,
                  :tar_host,
                  :tarball_path,
                  :team,
                  :templates,
                  :update_version_file,
                  :version,
                  :version_file,
                  :version_strategy,
                  :yum_archive_path,
                  :yum_host,
                  :yum_repo_path,
                  :yum_repo_name,
                  :yum_repo_command,
  ]

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

    mixed_params = { :sign_tar => true, :baz => 'qux' }
    context "given a hash with both valid and invalid params" do
      it "should set the valid param" do
        Pkg::Config.should_receive(:instance_variable_set).with("@sign_tar", true)
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
      Build_Params.each { |param| params.has_key?(param).should == true }
    end
  end

  describe "#platform_data" do
    platform_tags = [
      'osx-10.15-x86_64',
      'osx-11-x86_64',
      'ubuntu-16.04-i386',
      'el-6-x86_64',
      'el-7-ppc64le',
      'sles-12-x86_64',
    ]

    artifacts = \
      "./artifacts/apple/10.15/PC1/x86_64/puppet-agent-5.3.2.658.gc79ef9a-1.osx10.15.dmg\n" \
      "./artifacts/apple/11/PC1/x86_64/puppet-agent-5.3.2.658.gc79ef9a-1.osx11.dmg\n" \
      "./artifacts/deb/xenial/PC1/puppet-agent_5.3.2-1xenial_i386.deb\n" \
      "./artifacts/el/6/PC1/x86_64/puppet-agent-5.3.2.658.gc79ef9a-1.el6.x86_64.rpm\n" \
      "./artifacts/el/7/PC1/ppc64le/puppet-agent-5.3.2-1.el7.ppc64le.rpm\n" \
      "./artifacts/sles/12/PC1/x86_64/puppet-agent-5.3.2-1.sles12.x86_64.rpm"

    aix_artifacts = \
      "./artifacts/aix/7.1/PC1/ppc/puppet-agent-5.3.2-1.aix7.1.ppc.rpm"

    fedora_artifacts = \
      "./artifacts/fedora/32/PC1/x86_64/puppet-agent-5.3.2-1.fc32.x86_64.rpm"

    windows_artifacts = \
      "./artifacts/windows/puppet-agent-x64.msi\n" \
      "./artifacts/windows/puppet-agent-5.3.2-x86.wixpdb\n" \
      "./artifacts/windows/puppet-agent-5.3.2-x86.msi\n" \
      "./artifacts/windows/puppet-agent-5.3.2-x64.msi\n"\
      "./artifacts/windowsfips/puppet-agent-x64.msi\n" \
      "./artifacts/windowsfips/puppet-agent-5.3.2-x64.msi"

    solaris_artifacts = \
      "./artifacts/solaris/11/PC1/puppet-agent@5.3.2,5.11-1.sparc.p5p\n" \
      "./artifacts/solaris/10/PC1/puppet-agent-5.3.2-1.i386.pkg.gz"

    stretch_artifacts = \
      "./artifacts/deb/stretch/PC1/puppet-agent-dbgsym_5.3.2-1stretch_i386.deb\n" \
      "./artifacts/deb/stretch/PC1/puppet-agent_5.3.2-1stretch_i386.deb\n" \
      "./artifacts/deb/stretch/PC1/puppet-agent_5.3.2.658.gc79ef9a-1stretch_amd64.deb\n" \
      "./artifacts/deb/stretch/PC1/puppet-agent-dbgsym_5.3.2.658.gc79ef9a-1stretch_amd64.deb"

    artifacts_not_matching_project = \
      "./artifacts/deb/xenial/pe-postgresql-contrib_2019.1.9.6.12-1xenial_amd64.deb\n" \
      "./artifacts/deb/xenial/pe-postgresql-devel_2019.1.9.6.12-1xenial_amd64.deb\n" \
      "./artifacts/deb/xenial/pe-postgresql-server_2019.1.9.6.12-1xenial_amd64.deb\n" \
      "./artifacts/deb/xenial/pe-postgresql_2019.1.9.6.12-1xenial_amd64.deb"
    project = 'puppet-agent'
    ref = '5.3.2'

    before :each do
      allow(Pkg::Config).to receive(:project).and_return(project)
      allow(Pkg::Config).to receive(:ref).and_return(ref)
      allow(Pkg::Util::Net).to receive(:check_host_ssh).and_return([])
    end

    it "should return a hash mapping platform tags to paths" do
      allow(Pkg::Util::Net).to receive(:remote_execute).and_return(artifacts, nil)
      expect(Pkg::Config.platform_data.keys).to eql(platform_tags)
    end

    it "should return nil if project isn't set" do
      allow(Pkg::Config).to receive(:project).and_return(nil)
      expect(Pkg::Config.platform_data).to be_nil
    end

    it "should return nil if ref isn't set" do
      allow(Pkg::Config).to receive(:ref).and_return(nil)
      expect(Pkg::Config.platform_data).to be_nil
    end

    it "should return nil if can't connect to build server" do
      allow(Pkg::Util::Net).to receive(:check_host_ssh).and_return(['something'])
      expect(Pkg::Config.platform_data).to be_nil
    end

    it "should not use 'f' in fedora platform tags" do
      allow(Pkg::Util::Net).to receive(:remote_execute).and_return(fedora_artifacts, nil)
      data = Pkg::Config.platform_data
      expect(data).to include('fedora-32-x86_64')
      expect(data).not_to include('fedora-f32-x86_64')
    end

    it "should collect packages whose extname differ from package_format" do
      allow(Pkg::Util::Net).to receive(:remote_execute).and_return(solaris_artifacts, nil)
      data = Pkg::Config.platform_data
      expect(data).to include('solaris-10-i386' => {:artifact => './solaris/10/PC1/puppet-agent-5.3.2-1.i386.pkg.gz', :repo_config => nil})
      expect(data).to include('solaris-11-sparc' => {:artifact => './solaris/11/PC1/puppet-agent@5.3.2,5.11-1.sparc.p5p', :repo_config => nil})
    end

    it "should collect versioned msis" do
      allow(Pkg::Util::Net).to receive(:remote_execute).and_return(windows_artifacts, nil)
      data = Pkg::Config.platform_data
      expect(data['windows-2012-x86']).to include(:artifact => './windows/puppet-agent-5.3.2-x86.msi')
      expect(data['windows-2012-x64']).to include(:artifact => './windows/puppet-agent-5.3.2-x64.msi')
      expect(data['windowsfips-2012-x64']).to include(:artifact => './windowsfips/puppet-agent-5.3.2-x64.msi')
    end

    it "should not collect debug packages" do
      allow(Pkg::Util::Net).to receive(:remote_execute).and_return(stretch_artifacts, nil)
      data = Pkg::Config.platform_data
      expect(data['debian-9-amd64']).to include(:artifact => './deb/stretch/PC1/puppet-agent_5.3.2.658.gc79ef9a-1stretch_amd64.deb')
    end

    it "should collect packages that don't match the project name" do
      allow(Pkg::Util::Net).to receive(:remote_execute).and_return(artifacts_not_matching_project, nil)
      data = Pkg::Config.platform_data
      expect(data['ubuntu-16.04-amd64']).to include(:artifact => './deb/xenial/pe-postgresql-contrib_2019.1.9.6.12-1xenial_amd64.deb')
      expect(data['ubuntu-16.04-amd64'][:additional_artifacts].size).to eq(3)
      expect(data['ubuntu-16.04-amd64'][:additional_artifacts]).to include('./deb/xenial/pe-postgresql-devel_2019.1.9.6.12-1xenial_amd64.deb')
      expect(data['ubuntu-16.04-amd64'][:additional_artifacts]).to include('./deb/xenial/pe-postgresql-server_2019.1.9.6.12-1xenial_amd64.deb')
      expect(data['ubuntu-16.04-amd64'][:additional_artifacts]).to include('./deb/xenial/pe-postgresql_2019.1.9.6.12-1xenial_amd64.deb')
    end

    it "should use 'ppc' instead of 'power' in aix paths" do
      allow(Pkg::Util::Net).to receive(:remote_execute).and_return(aix_artifacts, nil)
      data = Pkg::Config.platform_data
      expect(data['aix-7.1-power']).to include(:artifact => './aix/7.1/PC1/ppc/puppet-agent-5.3.2-1.aix7.1.ppc.rpm')
    end

    it "should not record an aix repo config" do
      allow(Pkg::Util::Net).to receive(:remote_execute).and_return(aix_artifacts, nil)
      data = Pkg::Config.platform_data
      expect(data['aix-7.1-power'][:repo_config]).to be_nil
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
        Pkg::Config.config_from_yaml(File.join(FIXTURES, 'config', 'ext', 'build_defaults.yaml'))
        expect(Pkg::Config.apt_host).to eq("foo")
        Pkg::Config.apt_host = orig
      end
    end
  end

  describe "#string_to_array" do
    ary = %W(FOO BAR ARR RAY)
    context "given a string with spaces in it" do
      it "should return an array containing the contents of that string" do
        space_str = "FOO BAR ARR RAY"
        expect(Pkg::Config.string_to_array(space_str)).to eq(ary)
      end
    end

    context "given a string with commas in it" do
      it "should return an array containing the contents of that string" do
        comma_str = "FOO,BAR,ARR,RAY"
        expect(Pkg::Config.string_to_array(comma_str)).to eq(ary)
      end
    end

    context "given a string with semicolons in it" do
      it "should return an array containing the contents of that string" do
        semi_str = "FOO;BAR;ARR;RAY"
        expect(Pkg::Config.string_to_array(semi_str)).to eq(ary)
      end
    end

    context "given a string with multiple delimiters in it" do
      delimiters = [',', ' ', ';']
      mixed_str = "FOO, BAR, ARR, ; RAY"
      mixed_arr = Pkg::Config.string_to_array(mixed_str)

      it "should not return the delimiters as array items" do
        expect(mixed_arr).to_not include(*delimiters)
      end

      it "should not contain empty strings" do
        expect(mixed_arr).to_not include("\s")
      end

      it "should still return the expected array" do
        expect(mixed_arr).to eq(ary)
      end
    end
  end

  describe "#cow_list" do
    it "should return a list of the cows for a project" do
      Pkg::Config.cows = "base-lucid-i386.cow base-lucid-amd64.cow base-precise-i386.cow base-precise-amd64.cow base-quantal-i386.cow base-quantal-amd64.cow base-saucy-i386.cow base-saucy-amd64.cow base-sid-i386.cow base-sid-amd64.cow base-squeeze-i386.cow base-squeeze-amd64.cow base-stable-i386.cow base-stable-amd64.cow base-testing-i386.cow base-testing-amd64.cow base-trusty-i386.cow base-trusty-amd64.cow base-unstable-i386.cow base-unstable-amd64.cow base-wheezy-i386.cow base-wheezy-amd64.cow"
      Pkg::Config.cow_list.should eq "lucid precise quantal saucy sid squeeze stable testing trusty unstable wheezy"
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
    around do |example|
      prev_tar_host = Pkg::Config.tar_host
      Pkg::Config.tar_host = nil
      example.run
      Pkg::Config.tar_host = prev_tar_host
    end

    it "should set tar_host to staging_server" do
      Pkg::Config.config_from_hash({ :staging_server => 'foo' })
      Pkg::Config.issue_reassignments
      Pkg::Config.tar_host.should eq("foo")
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
    before(:each) do
      @project_root = double('project_root')
      Pkg::Config.project_root = @project_root
      @test_project_data = File.join(Pkg::Config.project_root, 'ext', 'project_data.yaml')
      @test_build_defaults = File.join(Pkg::Config.project_root, 'ext', 'build_defaults.yaml')
    end

    around do |example|
      orig = Pkg::Config.project_root
      example.run
      Pkg::Config.project_root = orig
    end

    context "given ext/build_defaults.yaml and ext/project_data.yaml are readable" do
      it "should try to load build_defaults.yaml and project_data.yaml" do
        allow(File).to receive(:readable?).with(@test_project_data).and_return(true)
        allow(File).to receive(:readable?).with(@test_build_defaults).and_return(true)
        expect(Pkg::Config).to receive(:config_from_yaml).with(@test_project_data)
        expect(Pkg::Config).to receive(:config_from_yaml).with(@test_build_defaults)
        Pkg::Config.load_default_configs
      end
    end

    context "given ext/build_defaults.yaml is readable but ext/project_data.yaml is not" do
      it "should try to load build_defaults.yaml but not project_data.yaml" do
        allow(File).to receive(:readable?).with(@test_project_data).and_return(false)
        allow(File).to receive(:readable?).with(@test_build_defaults).and_return(true)
        expect(Pkg::Config).to_not receive(:config_from_yaml).with(@test_project_data)
        expect(Pkg::Config).to receive(:config_from_yaml).with(@test_build_defaults)
        Pkg::Config.load_default_configs
      end
    end

    context "given ext/build_defaults.yaml is not readable but ext/project_data.yaml is" do
      it "should try to load build_defaults.yaml then unset project_root" do
        allow(File).to receive(:readable?).with(@test_project_data).and_return(true)
        allow(File).to receive(:readable?).with(@test_build_defaults).and_return(false)
        expect(Pkg::Config).to_not receive(:config_from_yaml).with(@test_build_defaults)
        Pkg::Config.load_default_configs
        expect(Pkg::Config.project_root).to be_nil
      end
    end

    context "given ext/build_defaults.yaml and ext/project_data.yaml are not readable" do
      it "should not try to load build_defaults.yaml and project_data.yaml" do
        Pkg::Config.project_root = 'foo'
        expect(Pkg::Config).to_not receive(:config_from_yaml)
        Pkg::Config.load_default_configs
      end

      it "should set the project root to nil" do
        Pkg::Config.project_root = 'foo'
        Pkg::Config.load_default_configs
        expect(Pkg::Config.project_root).to be_nil
      end
    end
  end

  describe "#load_versioning" do
    around do |example|
      orig = Pkg::Config.project_root
      example.run
      Pkg::Config.project_root = orig
    end

    # We let the actual version determination testing happen in the version
    # tests. Here we just test that we try when we should.
    context "When project root is nil" do
      it "should not try to load versioning" do
        Pkg::Config.project_root = nil
        expect(Pkg::Util::Version).to_not receive(:git_sha_or_tag)
        Pkg::Config.load_versioning
      end
    end
  end

  describe "#load_envvars" do
    # We're going to pollute the environment with this test, so afterwards we
    # explicitly set everything to nil to prevent any hazardous effects on
    # the rest of the tests.
    after(:all) do
      reset_env(Pkg::Params::ENV_VARS.map {|hash| hash[:envvar].to_s})
    end

    Pkg::Params::ENV_VARS.each do |v|
      case v[:type]
      when :bool
        it "should set boolean value on #{v[:var]} for :type == :bool" do
          ENV[v[:envvar].to_s] = "FOO"
          Pkg::Util.stub(:boolean_value) {"FOO"}
          allow(Pkg::Config).to receive(:instance_variable_set)
          expect(Pkg::Util).to receive(:boolean_value).with("FOO")
          expect(Pkg::Config).to receive(:instance_variable_set).with("@#{v[:var]}", "FOO")
          Pkg::Config.load_envvars
        end
      when :array
        it "should set Pkg::Config##{v[:var]} to an Array for :type == :array" do
          ENV[v[:envvar].to_s] = "FOO BAR ARR RAY"
          Pkg::Config.stub(:string_to_array) {%w(FOO BAR ARR RAY)}
          allow(Pkg::Config).to receive(:instance_variable_set)
          expect(Pkg::Config).to receive(:string_to_array).with("FOO BAR ARR RAY")
          expect(Pkg::Config).to receive(:instance_variable_set).with("@#{v[:var]}", %w(FOO BAR ARR RAY))
          Pkg::Config.load_envvars
        end
      else
        it "should set Pkg::Config##{v[:var]} to ENV[#{v[:envvar].to_s}]" do
          ENV[v[:envvar].to_s] = "FOO"
          Pkg::Util.stub(:boolean_value) {"FOO"}
          allow(Pkg::Config).to receive(:instance_variable_set)
          expect(Pkg::Config).to receive(:instance_variable_set).with("@#{v[:var]}", "FOO")
          Pkg::Config.load_envvars
        end
      end
    end
  end
end
