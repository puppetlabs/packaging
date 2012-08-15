require 'rubygems'
require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'yaml'
require 'benchmark'

@project_specs ||= YAML.load(File.read('ext/project_data.yaml'))
begin
  @name                   = @project_specs['project']
  @author                 = @project_specs['author']
  @email                  = @project_specs['email']
  @homepage               = @project_specs['homepage']
  @summary                = @project_specs['summary']
  @description            = @project_specs['description']
  @files                  = @project_specs['files']
  @gem_files              = @project_specs['gem_files']
  @gem_require_path       = @project_specs['gem_require_path']
  @gem_test_files         = @project_specs['gem_test_files']
  @gem_executables        = @project_specs['gem_executables']
  @gem_default_executable = @project_specs['gem_default_executables']
rescue
  STDERR.puts "There was an error loading the project specifications from the data.yaml file."
  exit 1
end

@pkg_defaults ||= YAML.load(File.read('ext/build_defaults.yaml'))
begin
  @cow          = ENV['COW']          || @pkg_defaults['cow']
  @pbuild_conf  = ENV['PBUILDCONF']   || @pkg_defaults['pbuild_conf']
  @deb_packager = ENV['DEB_PACKAGER'] || @pkg_defaults['deb_packager']
  @sign_srpm    = ENV['SIGN_SRPM']    || @pkg_defaults['sign_srpm']
  @final_mocks  = ENV['MOCK']         || @pkg_defaults['final_mocks']
  @rc_mocks     = ENV['MOCK']         || @pkg_defaults['rc_mocks']
  @gpg_name     = ENV['GPG_NAME']     || @pkg_defaults['gpg_name']
  @gpg_key      = ENV['GPG_KEY']      || @pkg_defaults['gpg_key']
  @version_file = @pkg_defaults['version_file']
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
