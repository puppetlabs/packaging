require 'yaml'
require 'erb'
require 'benchmark'

begin
  @project_specs            ||= YAML.load_file('ext/project_data.yaml')
  @name                     = @project_specs['project']
  @author                   = @project_specs['author']
  @email                    = @project_specs['email']
  @homepage                 = @project_specs['homepage']
  @summary                  = @project_specs['summary']
  @description              = @project_specs['description']
  @files                    = @project_specs['files']
  @tar_excludes             = @project_specs['tar_excludes']
  @version_file             = @project_specs['version_file']
  @gem_files                = @project_specs['gem_files']
  @gem_require_path         = @project_specs['gem_require_path']
  @gem_test_files           = @project_specs['gem_test_files']
  @gem_executables          = @project_specs['gem_executables']
  @gem_runtime_dependencies = @project_specs['gem_runtime_dependencies']
  @gem_devel_dependencies   = @project_specs['gem_devel_dependencies']
  @gem_rdoc_options         = @project_specs['gem_rdoc_options']
  @gem_forge_project        = @project_specs['gem_forge_project']
  @gem_excludes             = @project_specs['gem_excludes']
rescue => e
  STDERR.puts "There was an error loading the project specifications from the 'ext/project_data.yaml' file.\n" + e
  exit 1
end

begin
  @pkg_defaults    ||= YAML.load_file('ext/build_defaults.yaml')
  @sign_tar        = boolean_value( ENV['SIGN_TAR'] || @pkg_defaults['sign_tar']  )
  @build_gem       = boolean_value( ENV['GEM']      || @pkg_defaults['build_gem'] )
  @build_dmg       = boolean_value( ENV['DMG']      || @pkg_defaults['build_dmg'] )
  @build_ips       = boolean_value( ENV['IPS']      || @pkg_defaults['build_ips'] )
  @build_doc       = boolean_value( ENV['DOC']      || @pkg_defaults['build_doc'] )
  @build_pe        = boolean_value( ENV['PE_BUILD'] || @pkg_defaults['build_pe'] )
  @default_cow     = ENV['COW']          || @pkg_defaults['default_cow']
  @cows            = ENV['COW']          || @pkg_defaults['cows']
  @pbuild_conf     = ENV['PBUILDCONF']   || @pkg_defaults['pbuild_conf']
  @packager        = ENV['PACKAGER']     || @pkg_defaults['packager']
  @default_mock    = ENV['MOCK']         || @pkg_defaults['default_mock']
  @final_mocks     = ENV['MOCK']         || @pkg_defaults['final_mocks']
  @rc_mocks        = ENV['MOCK']         || @pkg_defaults['rc_mocks']
  @gpg_name        = ENV['GPG_NAME']     || @pkg_defaults['gpg_name']
  @gpg_key         = ENV['GPG_KEY']      || @pkg_defaults['gpg_key']
  @certificate_pem = ENV['CERT_PEM']     || @pkg_defaults['certificate_pem']
  @privatekey_pem  = ENV['PRIVATE_PEM']  || @pkg_defaults['privatekey_pem']
  @yum_host        = ENV['YUM_HOST']     || @pkg_defaults['yum_host']
  @yum_repo_path   = ENV['YUM_REPO']     || @pkg_defaults['yum_repo_path']
  @apt_host        = ENV['APT_HOST']     || @pkg_defaults['apt_host']
  @apt_repo_path   = ENV['APT_REPO']     || @pkg_defaults['apt_repo_path']
  @apt_repo_url    = @pkg_defaults['apt_repo_url']
  @ips_repo        = @pkg_defaults['ips_repo']
  @ips_store       = @pkg_defaults['ips_store']
  @ips_host        = @pkg_defaults['ips_host']
  @ips_inter_cert  = @pkg_defaults['ips_inter_cert']
rescue => e
  STDERR.puts "There was an error loading the packaging defaults from the 'ext/build_defaults.yaml' file.\n" + e
  exit 1
end

@build_root        ||= Dir.pwd
@release           ||= get_release
@version           ||= get_dash_version
@gemversion        ||= get_dot_version
@ipsversion        ||= get_ips_version
@debversion        ||= get_debversion
@origversion       ||= get_origversion
@rpmversion        ||= get_rpmversion
@rpmrelease        ||= get_rpmrelease
@keychain_loaded   ||= FALSE
@builder_data_file ||= 'builder_data.yaml'
@team              = ENV['TEAM'] || 'dev'
