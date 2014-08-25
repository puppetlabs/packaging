# These are all of the parameters known to our packaging system.
# They are ingested by the config class as class instance variables
module Pkg::Params
  BUILD_PARAMS = [:apt_host,
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
                  :build_msi,
                  :build_pe,
                  :builder_data_file,
                  :builds_server,
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
                  :distribution_server,
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
                  :project_root,
                  :random_mockroot,
                  :rc_mocks,
                  :redis_hostname,
                  :release,
                  :rpm_build_host,
                  :rpmrelease,
                  :rpmversion,
                  :ref,
                  :sign_tar,
                  :signing_server,
                  :summary,
                  :tar_excludes,
                  :tar_host,
                  :tarball_path,
                  :task,
                  :team,
                  :templates,
                  :update_version_file,
                  :version,
                  :version_file,
                  :version_strategy,
                  :yum_host,
                  :yum_repo_path,
                  :internal_gem_host]

  # Environment variable overrides for Pkg::Config parameters
  #
  #           :var  => :config_param,    :envvar => :environment var :type => :variable type
  #
  #           Note: :type is assumed :string if not present
  #
  ENV_VARS = [{ :var => :apt_host,            :envvar => :APT_HOST },
              { :var => :apt_repo_path,       :envvar => :APT_REPO },
              { :var => :build_dmg,           :envvar => :DMG,             :type => :bool },
              { :var => :build_doc,           :envvar => :DOC,             :type => :bool },
              { :var => :build_gem,           :envvar => :GEM,             :type => :bool },
              { :var => :build_ips,           :envvar => :IPS,             :type => :bool },
              { :var => :build_pe,            :envvar => :PE_BUILD,        :type => :bool },
              { :var => :certificate_pem,     :envvar => :CERT_PEM },
              { :var => :cows,                :envvar => :COW },
              { :var => :debug,               :envvar => :DEBUG,           :type => :bool },
              { :var => :default_cow,         :envvar => :COW },
              { :var => :default_mock,        :envvar => :MOCK },
              { :var => :final_mocks,         :envvar => :MOCK },
              { :var => :gpg_name,            :envvar => :GPG_NAME },
              { :var => :gpg_key,             :envvar => :GPG_KEY },
              { :var => :notify,              :envvar => :NOTIFY },
              { :var => :packager,            :envvar => :PACKAGER },
              { :var => :pbuild_conf,         :envvar => :PBUILDCONF },
              { :var => :pe_version,          :envvar => :PE_VER },
              { :var => :privatekey_pem,      :envvar => :PRIVATE_PEM },
              { :var => :project_root,        :envvar => :PROJECT_ROOT },
              { :var => :random_mockroot,     :envvar => :RANDOM_MOCKROOT, :type => :bool },
              { :var => :rc_mocks,            :envvar => :MOCK },
              { :var => :release,             :envvar => :RELEASE },
              { :var => :signing_server,      :envvar => :SIGNING_SERVER },
              { :var => :sign_tar,            :envvar => :SIGN_TAR,        :type => :bool },
              { :var => :team,                :envvar => :TEAM },
              { :var => :update_version_file, :envvar => :NEW_STYLE_PACKAGE },
              { :var => :yum_repo_path,       :envvar => :YUM_REPO },
              { :var => :yum_host,            :envvar => :YUM_HOST }]
  # Default values that are supplied if the user does not supply them
  #
  # usage is the same as above
  #
  DEFAULTS = [{ :var => :builder_data_file, :val => 'builder_data.yaml' },
              { :var => :team,              :val => 'dev' },
              { :var => :random_mockroot,   :val => true },
              { :var => :keychain_loaded,   :val => false },
              { :var => :build_date,        :val => Pkg::Util::Date.timestamp('-') },
              { :var => :release,           :val => '1' },
              { :var => :internal_gem_host, :val => 'http://rubygems.delivery.puppetlabs.net/' }]

  # These are variables which, over time, we decided to rename or replace. For
  # backwards compatibility, we assign the value of the old/deprecated
  # variables, if set, to the new ones. We also use this method for accessor
  # "redirects" - e.g. defaulting the populated value of one parameter for another
  # in case it is not set.
  #
  REASSIGNMENTS = [{ :oldvar => :name,                   :newvar => :project },
                   { :oldvar => :yum_host,               :newvar => :tar_host },
                   { :oldvar => :gem_devel_dependencies, :newvar => :gem_development_dependencies },
                   { :oldvar => :pe_name,                :newvar => :project },
                   { :oldvar => :project,                :newvar => :gem_name },
                   { :oldvar => :gpg_name,               :newvar => :gpg_key }]

  # These are variables that we have deprecated. If they are encountered in a
  # project's config, we issue deprecations for them.
  #
  DEPRECATIONS = [{ :var => :gem_devel_dependencies, :message => "
    DEPRECATED, 9-Nov-2013: 'gem_devel_dependencies' has been replaced with
    'gem_development_dependencies.' Please update this field in your
    project_data.yaml" },
                  { :var => :gpg_name, :message => "
    DEPRECATED, 29-Jul-2014: 'gpg_name' has been replaced with 'gpg_key'.
                   Please update this field in your project_data.yaml" }]

end

