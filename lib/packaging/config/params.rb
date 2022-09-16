require "packaging/platforms"

# These are all of the parameters known to our packaging system.
# They are ingested by the config class as class instance variables
module Pkg::Params
  BUILD_PARAMS = %i[allow_dirty_tree
                  answer_override
                  apt_archive_path
                  apt_archive_repo_command
                  apt_host
                  apt_releases
                  apt_repo_command
                  apt_repo_name
                  apt_repo_path
                  apt_repo_staging_path
                  apt_repo_url
                  apt_signing_server
                  apt_staging_server
                  author
                  benchmark
                  build_data_repo
                  build_date
                  build_defaults
                  build_dmg
                  build_doc
                  build_gem
                  build_ips
                  build_msi
                  build_pe
                  build_tar
                  builder_data_file
                  builds_server
                  bundle_platforms
                  certificate_pem
                  cows
                  db_table
                  deb_build_host
                  deb_build_mirrors
                  deb_targets
                  debug
                  debversion
                  default_cow
                  default_mock
                  dev_build
                  description
                  distribution_server
                  dmg_host
                  dmg_path
                  dmg_staging_server
                  downloads_archive_path
                  email
                  files
                  final_mocks
                  foss_only
                  foss_platforms
                  freight_archive_path
                  freight_conf
                  gcp_signed_bucket
                  gcp_tosign_bucket
                  gem_default_executables
                  gem_dependencies
                  gem_description
                  gem_devel_dependencies
                  gem_development_dependencies
                  gem_excludes
                  gem_executables
                  gem_files
                  gem_forge_project
                  gem_host
                  gem_license
                  gem_name
                  gem_path
                  gem_platform_dependencies
                  gem_rdoc_options
                  gem_require_path
                  gem_required_ruby_version
                  gem_required_rubygems_version
                  gem_runtime_dependencies
                  gem_summary
                  gem_test_files
                  gemversion
                  gpg_key
                  gpg_name
                  homepage
                  internal_gem_host
                  ips_build_host
                  ips_host
                  ips_inter_cert
                  ips_package_host
                  ips_path
                  ips_repo
                  ips_root_cert
                  ips_signing_cert
                  ips_signing_key
                  ips_signing_server
                  ips_signing_ssh_key
                  ips_store
                  jenkins_build_host
                  jenkins_packaging_job
                  jenkins_repo_path
                  metrics
                  metrics_url
                  msi_host
                  msi_name
                  msi_path
                  msi_signing_gcp_service_account_credentials
                  msi_signing_service_url
                  msi_staging_server
                  name
                  nonfinal_apt_repo_command
                  nonfinal_apt_repo_path
                  nonfinal_apt_repo_staging_path
                  nonfinal_dmg_path
                  nonfinal_gem_path
                  nonfinal_ips_path
                  nonfinal_msi_path
                  nonfinal_p5p_path
                  nonfinal_repo_name
                  nonfinal_repo_link_target
                  nonfinal_svr4_path
                  nonfinal_swix_path
                  nonfinal_yum_repo_path
                  notify
                  nuget_host
                  nuget_repo_path
                  origversion
                  osx_build_host
                  osx_signing_cert
                  osx_signing_keychain
                  osx_signing_keychain_pw
                  osx_signing_server
                  osx_signing_ssh_key
                  p5p_host
                  p5p_path
                  packager
                  packaging_repo
                  packaging_root
                  packaging_url
                  pbuild_conf
                  pe_feature_branch
                  pe_release_branch
                  pe_name
                  pe_platforms
                  pe_version
                  pg_major_version
                  platform_repos
                  pre_tar_task
                  pre_tasks
                  privatekey_pem
                  project
                  project_root
                  random_mockroot
                  rc_mocks
                  redis_hostname
                  ref
                  release
                  repo_link_target
                  repo_name
                  rpm_build_host
                  rpm_targets
                  rpmrelease
                  rpmversion
                  rsync_servers
                  s3_ship
                  short_ref
                  sign_tar
                  signing_server
                  staging_server
                  summary
                  svr4_host
                  svr4_path
                  swix_host
                  swix_path
                  swix_staging_server
                  tar_excludes
                  tar_host
                  tar_staging_server
                  tarball_path
                  task
                  team
                  templates
                  update_version_file
                  vanagon_project
                  version
                  version_file
                  version_strategy
                  yum_archive_path
                  yum_host
                  yum_repo_command
                  yum_repo_name
                  yum_repo_path
                  yum_staging_server]

  # Environment variable overrides for Pkg::Config parameters
  #
  #           :var  => :config_param,    :envvar => :environment var :type => :variable type
  #
  #           Note: :type is assumed :string if not present
  #
  ENV_VARS = [
              { :var => :allow_dirty_tree,        :envvar => :ALLOW_DIRTY_TREE, :type => :bool },
              { :var => :answer_override,         :envvar => :ANSWER_OVERRIDE },
              { :var => :apt_archive_path,        :envvar => :APT_ARCHIVE_PATH },
              { :var => :apt_archive_repo_command, :envvar => :APT_ARCHIVE_REPO_COMMAND },
              { :var => :apt_host,                :envvar => :APT_HOST },
              { :var => :apt_releases,            :envvar => :APT_RELEASES, :type => :array },
              { :var => :apt_repo_path,           :envvar => :APT_REPO },
              { :var => :apt_repo_staging_path,   :envvar => :APT_REPO_STAGING_PATH },
              { :var => :apt_signing_server,      :envvar => :APT_SIGNING_SERVER },
              { :var => :apt_staging_server,      :envvar => :APT_STAGING_SERVER },
              { :var => :build_data_repo,         :envvar => :BUILD_DATA_REPO },
              { :var => :build_dmg,               :envvar => :DMG,             :type => :bool },
              { :var => :build_doc,               :envvar => :DOC,             :type => :bool },
              { :var => :build_gem,               :envvar => :GEM,             :type => :bool },
              { :var => :build_ips,               :envvar => :IPS,             :type => :bool },
              { :var => :build_msi,               :envvar => :MSI,             :type => :bool },
              { :var => :build_pe,                :envvar => :PE_BUILD,        :type => :bool },
              { :var => :build_tar,               :envvar => :TAR,             :type => :bool },
              { :var => :certificate_pem,         :envvar => :CERT_PEM },
              { :var => :cows,                    :envvar => :COW },
              { :var => :debug,                   :envvar => :DEBUG, :type => :bool },
              { :var => :default_cow,             :envvar => :COW },
              { :var => :default_mock,            :envvar => :MOCK },
              { :var => :dev_build,               :envvar => :DEV_BUILD, :type => :bool },
              { :var => :dmg_host,                :envvar => :DMG_HOST },
              { :var => :dmg_path,                :envvar => :DMG_PATH },
              { :var => :dmg_staging_server,      :envvar => :DMG_STAGING_SERVER },
              { :var => :downloads_archive_path,  :envvar => :DOWNLOADS_ARCHIVE_PATH },
              { :var => :final_mocks,             :envvar => :MOCK },
              { :var => :foss_only,               :envvar => :FOSS_ONLY,       :type => :bool },
              { :var => :foss_platforms,          :envvar => :FOSS_PLATFORMS,  :type => :array },
              { :var => :freight_archive_path,    :envvar => :FREIGHT_ARCHIVE_PATH },
              { :var => :gcp_signed_bucket,       :envvar => :GCP_SIGNED_BUCKET },
              { :var => :gcp_tosign_bucket,       :envar  => :GCP_TOSIGN_BUCKET },
              { :var => :gem_host,                :envvar => :GEM_HOST },
              { :var => :gpg_key,                 :envvar => :GPG_KEY },
              { :var => :gpg_name,                :envvar => :GPG_NAME },
              { :var => :ips_host,                :envvar => :IPS_HOST },
              { :var => :ips_inter_cert,          :envvar => :IPS_INTER_CERT },
              { :var => :ips_path,                :envvar => :IPS_PATH },
              { :var => :ips_repo,                :envvar => :IPS_REPO },
              { :var => :ips_root_cert,           :envvar => :IPS_ROOT_CERT },
              { :var => :ips_signing_cert,        :envvar => :IPS_SIGNING_CERT },
              { :var => :ips_signing_key,         :envvar => :IPS_SIGNING_KEY },
              { :var => :ips_signing_server,      :envvar => :IPS_SIGNING_SERVER },
              { :var => :ips_signing_ssh_key,     :envvar => :IPS_SIGNING_SSH_KEY },
              { :var => :msi_host,                :envvar => :MSI_HOST },
              { :var => :msi_path,                :envvar => :MSI_PATH },
              { :var => :msi_signing_gcp_service_account_credentials, :envvar => :MSI_SIGNING_GCP_SERVICE_ACCOUNT_CREDENTIALS },
              { :var => :msi_signing_service_url, :envvar => :MSI_SIGNING_SERVICE_URL },
              { :var => :msi_staging_server,      :envvar => :MSI_STAGING_SERVER },
              { :var => :nonfinal_apt_repo_command, :envvar => :NONFINAL_APT_REPO_COMMAND },
              { :var => :nonfinal_apt_repo_path, :envvar => :NONFINAL_APT_REPO_PATH },
              { :var => :nonfinal_apt_repo_staging_path, :envvar => :NONFINAL_APT_REPO_STAGING_PATH },
              { :var => :nonfinal_dmg_path,       :envvar => :NONFINAL_DMG_PATH },
              { :var => :nonfinal_gem_path,       :envvar => :NONFINAL_GEM_PATH },
              { :var => :nonfinal_ips_path,       :envvar => :NONFINAL_IPS_PATH },
              { :var => :nonfinal_msi_path,       :envvar => :NONFINAL_MSI_PATH },
              { :var => :nonfinal_p5p_path,       :envvar => :NONFINAL_P5P_PATH },
              { :var => :nonfinal_repo_link_target, :envvar => :NONFINAL_REPO_LINK_TARGET },
              { :var => :nonfinal_repo_name,      :envvar => :NONFINAL_REPO_NAME },
              { :var => :nonfinal_svr4_path,      :envvar => :NONFINAL_SVR4_PATH },
              { :var => :nonfinal_swix_path,      :envvar => :NONFINAL_SWIX_PATH },
              { :var => :nonfinal_yum_repo_path,  :envvar => :NONFINAL_YUM_REPO_PATH },
              { :var => :notify,                  :envvar => :NOTIFY },
              { :var => :nuget_host,              :envvar => :NUGET_HOST },
              { :var => :nuget_repo_path,         :envvar => :NUGET_REPO },
              { :var => :osx_signing_cert,        :envvar => :OSX_SIGNING_CERT },
              { :var => :osx_signing_keychain,    :envvar => :OSX_SIGNING_KEYCHAIN },
              { :var => :osx_signing_keychain_pw, :envvar => :OSX_SIGNING_KEYCHAIN_PW },
              { :var => :osx_signing_server,      :envvar => :OSX_SIGNING_SERVER },
              { :var => :osx_signing_ssh_key,     :envvar => :OSX_SIGNING_SSH_KEY },
              { :var => :p5p_host,                :envvar => :P5P_HOST },
              { :var => :p5p_path,                :envvar => :P5P_PATH },
              { :var => :packager,                :envvar => :PACKAGER },
              { :var => :pbuild_conf,             :envvar => :PBUILDCONF },
              { :var => :pe_feature_branch,       :envvar => :PE_FEATURE_BRANCH },
              { :var => :pe_version,              :envvar => :PE_VER },
              { :var => :privatekey_pem,          :envvar => :PRIVATE_PEM },
              { :var => :project,                 :envvar => :PROJECT_OVERRIDE },
              { :var => :project_root,            :envvar => :PROJECT_ROOT },
              { :var => :random_mockroot,         :envvar => :RANDOM_MOCKROOT, :type => :bool },
              { :var => :rc_mocks,                :envvar => :MOCK },
              { :var => :release,                 :envvar => :RELEASE },
              { :var => :repo_name,               :envvar => :REPO_NAME },
              { :var => :repo_link_target,        :envvar => :REPO_LINK_TARGET },
              { :var => :s3_ship,                 :envvar => :S3_SHIP,         :type => :bool },
              { :var => :sign_tar,                :envvar => :SIGN_TAR,        :type => :bool },
              { :var => :signing_server,          :envvar => :SIGNING_SERVER },
              { :var => :staging_server,          :envvar => :STAGING_SERVER },
              { :var => :swix_host,               :envvar => :SWIX_HOST },
              { :var => :swix_staging_server,     :envvar => :SWIX_STAGING_SERVER },
              { :var => :svr4_host,               :envvar => :SVR4_HOST },
              { :var => :svr4_path,               :envvar => :SVR4_PATH },
              { :var => :swix_path,               :envvar => :SWIX_PATH },
              { :var => :tar_host,                :envvar => :TAR_HOST },
              { :var => :tar_staging_server,      :envvar => :TAR_STAGING_SERVER },
              { :var => :team,                    :envvar => :TEAM },
              { :var => :update_version_file,     :envvar => :NEW_STYLE_PACKAGE },
              { :var => :vanagon_project,         :envvar => :VANAGON_PROJECT, :type => :bool },
              { :var => :version,                 :envvar => :PACKAGING_PACKAGE_VERSION },
              { :var => :yum_archive_path,        :envvar => :YUM_ARCHIVE_PATH },
              { :var => :yum_host,                :envvar => :YUM_HOST },
              { :var => :yum_repo_path,           :envvar => :YUM_REPO },
              { :var => :yum_staging_server,      :envvar => :YUM_STAGING_SERVER },
              { :var => :internal_gem_host,       :envvar => :INTERNAL_GEM_HOST },
             ]
  # Default values that are supplied if the user does not supply them
  #
  # usage is the same as above
  #
  DEFAULTS = [{ :var => :allow_dirty_tree,        :val => false },
              { :var => :builder_data_file,       :val => 'builder_data.yaml' },
              { :var => :team,                    :val => 'dev' },
              { :var => :random_mockroot,         :val => true },
              { :var => :keychain_loaded,         :val => false },
              { :var => :foss_only,               :val => false },
              { :var => :build_data_repo,         :val => 'https://github.com/puppetlabs/build-data.git' },
              { :var => :build_date,              :val => Pkg::Util::Date.timestamp('-') },
              { :var => :release,                 :val => '1' },
              { :var => :internal_gem_host,       :val => 'https://artifactory.delivery.puppetlabs.net/artifactory/api/gems/rubygems' },
              { :var => :build_tar,               :val => true },
              { :var => :dev_build,               :val => false },
              { :var => :osx_signing_cert,        :val => '$OSX_SIGNING_CERT' },
              { :var => :osx_signing_keychain,    :val => '$OSX_SIGNING_KEYCHAIN' },
              { :var => :osx_signing_keychain_pw, :val => '$OSX_SIGNING_KEYCHAIN_PW' },
              { :var => :ips_signing_cert,        :val => '$IPS_SIGNING_CERT' },
              { :var => :ips_inter_cert,          :val => '$IPS_INTER_CERT' },
              { :var => :ips_root_cert,           :val => '$IPS_ROOT_CERT' },
              { :var => :ips_signing_key,         :val => '$IPS_SIGNING_KEY' },
              { :var => :pe_feature_branch,       :val => false },
              { :var => :pe_release_branch,       :val => false },
              { :var => :s3_ship,                 :val => false },
              { :var => :apt_releases,            :val => Pkg::Platforms.codenames }]

  # These are variables which, over time, we decided to rename or replace. For
  # backwards compatibility, we assign the value of the old/deprecated
  # variables, if set, to the new ones. We also use this method for accessor
  # "redirects" - e.g. defaulting the populated value of one parameter for another
  # in case it is not set.
  #
  REASSIGNMENTS = [
                    # These are fall-through values for shipping endpoints
                    { :oldvar => :staging_server,         :newvar => :apt_staging_server },
                    { :oldvar => :staging_server,         :newvar => :dmg_staging_server },
                    { :oldvar => :staging_server,         :newvar => :swix_staging_server },
                    { :oldvar => :staging_server,         :newvar => :tar_staging_server },
                    { :oldvar => :staging_server,         :newvar => :yum_staging_server },
                    # These are fall-through values for signing/repo endpoints
                    { :oldvar => :yum_staging_server,     :newvar => :yum_host },
                    { :oldvar => :apt_repo_staging_path,  :newvar => :apt_repo_path },
                    { :oldvar => :apt_signing_server,     :newvar => :apt_host },
                    # These are legitimately old values
                    { :oldvar => :gem_devel_dependencies, :newvar => :gem_development_dependencies },
                    { :oldvar => :gpg_name,               :newvar => :gpg_key },
                    { :oldvar => :name,                   :newvar => :project },
                    { :oldvar => :pe_name,                :newvar => :project },
                    { :oldvar => :project,                :newvar => :gem_name },
                    { :oldvar => :yum_host,               :newvar => :swix_host },
                    { :oldvar => :yum_host,               :newvar => :dmg_host },
                    { :oldvar => :yum_host,               :newvar => :tar_host },
                 ]


  # These are variables that we have deprecated. If they are encountered in a
  # project's config, we issue deprecations for them.
  #
  DEPRECATIONS = [{ :var => :gem_devel_dependencies, :message => "
    DEPRECATED, 9-Nov-2013: 'gem_devel_dependencies' has been replaced with
    'gem_development_dependencies.' Please update this field in your
    build_defaults.yaml or project_data.yaml" },
                  { :var => :gpg_name, :message => "
    DEPRECATED, 29-Jul-2014: 'gpg_name' has been replaced with 'gpg_key'.
                   Please update this field in your build_defaults.yaml" }]

  # Provide an open-ended template for validating BUILD_PARAMS.
  #
  # Each validatation contains the variable name as ':var' and a list of validations it
  # must pass from the Pkg::Params::Validations class.
  #
  VALIDATIONS = [
    { :var => :project, :validations => [:not_empty?] }
  ]
end
