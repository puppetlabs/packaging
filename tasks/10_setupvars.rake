require 'rubygems'
require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'yaml'
require 'benchmark'
require 'erb'

@project_specs ||= YAML.load(File.read('ext/project_data.yaml'))
begin
  @name                   = @project_specs['project']
  @author                 = @project_specs['author']
  @email                  = @project_specs['email']
  @homepage               = @project_specs['homepage']
  @summary                = @project_specs['summary']
  @description            = @project_specs['description']
  @files                  = @project_specs['files']
  @version_file           = @project_specs['version_file']
  @gem_files              = @project_specs['gem_files']
  @gem_require_path       = @project_specs['gem_require_path']
  @gem_test_files         = @project_specs['gem_test_files']
  @gem_executables        = @project_specs['gem_executables']
rescue
  STDERR.puts "There was an error loading the project specifications from the data.yaml file."
  exit 1
end

@pkg_defaults ||= YAML.load(File.read('ext/build_defaults.yaml'))
begin
  @default_cow    = ENV['COW']          || @pkg_defaults['default_cow']
  @cows           = ENV['COW']          || @pkg_defaults['cows']
  @pbuild_conf    = ENV['PBUILDCONF']   || @pkg_defaults['pbuild_conf']
  @packager       = ENV['PACKAGER']     || @pkg_defaults['packager']
  @sign_tar       = ENV['SIGN_TAR']     || @pkg_defaults['sign_tar']
  @final_mocks    = ENV['MOCK']         || @pkg_defaults['final_mocks']
  @rc_mocks       = ENV['MOCK']         || @pkg_defaults['rc_mocks']
  @gpg_name       = ENV['GPG_NAME']     || @pkg_defaults['gpg_name']
  @gpg_key        = ENV['GPG_KEY']      || @pkg_defaults['gpg_key']
  @build_gem      = ENV['GEM']          || @pkg_defaults['build_gem']
  @yum_host       = @pkg_defaults['yum_host']
  @yum_repo_path  = @pkg_defaults['yum_repo_path']
  @apt_host       = @pkg_defaults['apt_host']
  @apt_repo_url   = @pkg_defaults['apt_repo_url']
  @apt_repo_path  = @pkg_defaults['apt_repo_path']
rescue
  STDERR.puts "There was an error loading the packaging defaults from the data.yaml file."
  exit 1
end

@build_root   ||= Dir.pwd
@version      ||= get_version
@debversion   ||= get_debversion
@origversion  ||= get_origversion
@rpmversion   ||= get_rpmversion
@release      ||= get_release
