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
  @gem_require_path       = @project_specs['require_path']
  @gem_test_files         = @project_specs['test_files']
  @gem_executables        = @project_specs['executables']
  @gem_default_executable = @project_specs['default_executables']
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

spec = Gem::Specification.new do |s|
  s.name = @name
  s.version = described_version
  s.author = @author
  s.email = @email
  s.homepage = @homepage
  s.summary = @summary
  s.description = @description
  s.files = FileList[@files].to_a
  s.require_path = @gem_require_path
  s.test_files = FileList[@gem_test_files].to_a
  s.executables = @gem_executables
  s.default_executable = @gem_default_executable
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar_gz = true
end

