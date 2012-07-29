require 'rubygems'
require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'yaml'

Dir['tasks/**/*.rake'].each { |t| load t }

@project_specs ||= YAML.load(File.read('../specifications.yaml'))
begin
  @name               = @project_specs['project']
  @author             = @project_specs['author']
  @email              = @project_specs['email']
  @homepage           = @project_specs['homepage']
  @summary            = @project_specs['summary']
  @description        = @project_specs['description']
  @files              = @project_specs['files']
  @require_path       = @project_specs['require_path']
  @test_files         = @project_specs['test_files']
  @has_rdoc           = @project_specs['has_rdoc']
  @executables        = @project_specs['executables']
  @default_executable = @project_specs['default_executables']
  @deb_build_depends  = @project_specs['deb_build_depends']
  @deb_depends        = @project_specs['deb_depends']
rescue
  STDERR.puts "There was an error loading the project specifications from the specifications.yaml file."
  exit 1
end

spec = Gem::Specification.new do |s|
  s.name = @name
  # Tag the version you want to release via an annotated tag
  s.version = described_version
  s.author = @author
  s.email = @email
  s.homepage = @homepage
  s.summary = @summary
  s.description = @description
  s.files = FileList[@files].to_a
  s.require_path = @require_path
  s.test_files = FileList[@test_files].to_a
  s.has_rdoc = @has_rdoc
  s.executables = @executables
  s.default_executable = @default_executable
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar_gz = true
end

desc "Run all specs"
RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = File.read("spec/spec.opts").chomp || ""
end

task :default => [:test, :repackage]
