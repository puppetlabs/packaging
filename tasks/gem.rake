require 'rubygems/package_task'

def glob_gem_files
  gem_files = []
  gem_excludes_file_list = []
  gem_excludes_raw = Pkg::Config.gem_excludes.nil? ? [] : Pkg::Config.gem_excludes.split
  gem_excludes_raw << 'ext/packaging'
  gem_excludes_raw << 'pkg'
  gem_excludes_raw.each do |exclude|
    if File.directory?(exclude)
      gem_excludes_file_list += FileList["#{exclude}/**/*"]
    else
      gem_excludes_file_list << exclude
    end
  end
  files = FileList[Pkg::Config.gem_files.split]
  files.each do |file|
    if File.directory?(file)
      gem_files += FileList["#{file}/**/*"]
    else
      gem_files << file
    end
  end
  gem_files -= gem_excludes_file_list
end

def add_gem_dependency(opts = {})
  spec = opts[:spec]
  version = opts[:version]
  type = opts[:type].to_s
  gem = opts[:gem].to_s
  if opts[:version].nil? or opts[:version].empty?
    spec.send("add_#{type}_dependency".to_sym, gem)
  else
    spec.send("add_#{type}_dependency".to_sym, gem, version)
  end
  spec
end

def create_default_gem_spec
  spec = Gem::Specification.new do |s|
    s.name = Pkg::Config.project                                     unless Pkg::Config.project.nil?
    s.name = Pkg::Config.gem_name                                    unless Pkg::Config.gem_name.nil?
    s.version = Pkg::Config.gemversion                               unless Pkg::Config.gemversion.nil?
    s.author = Pkg::Config.author                                    unless Pkg::Config.author.nil?
    s.email = Pkg::Config.email                                      unless Pkg::Config.email.nil?
    s.homepage = Pkg::Config.homepage                                unless Pkg::Config.homepage.nil?
    s.summary = Pkg::Config.summary                                  unless Pkg::Config.summary.nil?
    s.summary = Pkg::Config.gem_summary                              unless Pkg::Config.gem_summary.nil?
    s.description = Pkg::Config.description                          unless Pkg::Config.description.nil?
    s.description = Pkg::Config.gem_description                      unless Pkg::Config.gem_description.nil?
    s.files = glob_gem_files                                         unless glob_gem_files.nil?
    s.executables = Pkg::Config.gem_executables                      unless Pkg::Config.gem_executables.nil?
    s.require_path = Pkg::Config.gem_require_path                    unless Pkg::Config.gem_require_path.nil?
    s.required_ruby_version = Pkg::Config.gem_required_ruby_version  unless Pkg::Config.gem_required_ruby_version.nil?
    s.required_rubygems_version = Pkg::Config.gem_required_rubygems_version unless Pkg::Config.gem_required_rubygems_version.nil?
    s.test_files = FileList[Pkg::Config.gem_test_files.split] unless Pkg::Config.gem_test_files.nil?
    s.rubyforge_project = Pkg::Config.gem_forge_project unless Pkg::Config.gem_forge_project.nil?
    Pkg::Config.gem_rdoc_options&.each do |option|
        s.rdoc_options << option
      end
  end

  Pkg::Config.gem_runtime_dependencies&.each do |gem, version|
      spec = add_gem_dependency(:spec => spec, :gem => gem, :version => version, :type => :runtime)
    end

  Pkg::Config.gem_development_dependencies&.each do |gem, version|
      spec = add_gem_dependency(:spec => spec, :gem => gem, :version => version, :type => :development)
    end
  spec
end

def create_gem(spec, gembuilddir)
  gem_files = glob_gem_files + FileList[(Pkg::Config.gem_test_files || '').split]
  workdir = File.join(Pkg::Util::File.mktemp)

  bench = Benchmark.realtime do
    Pkg::Util::File.install_files_into_dir(gem_files, workdir)

    cd workdir do
      gem_task = Gem::PackageTask.new(spec)
      gem_task.define
      Rake::Task[:gem].reenable
      Rake::Task[:gem].invoke
      rm_rf File.join("pkg", gembuilddir)
      mv Dir.glob("pkg/#{Pkg::Config.gem_name}-#{Pkg::Config.gemversion}*.gem"), File.join(Pkg::Config.project_root, "pkg")
    end
  end

  rm_rf workdir
  puts "Finished building in: #{bench}"
end

def create_default_gem
  spec = create_default_gem_spec
  create_gem(spec, "#{Pkg::Config.gem_name}-#{Pkg::Config.gemversion}")
end

def unknown_gems_platform?(platform)
  return true if platform.os == "unknown"

  false
end

def create_platform_specific_gems
  Pkg::Config.gem_platform_dependencies.each do |platform, dependency_hash|
    spec = create_default_gem_spec
    pf = Gem::Platform.new(platform)
    if unknown_gems_platform?(pf)
      fail "
        Platform: '#{platform}' is not recognized by rubygems.
        This is probably an erroneous 'gem_platform_dependencies' entry!"
    end
    spec.platform = pf
    dependency_hash.each do |type, gems|
      t = case type
      when "gem_runtime_dependencies"
        "runtime"
      when "gem_development_dependencies"
        "development"
      else
        fail "Platform specific gem dependency type must be 'gem_runtime_dependencies' or 'gem_development_dependencies', not '#{type}'"
      end
      gems.each do |gem, version|
        spec = add_gem_dependency(:spec => spec, :gem => gem, :version => version, :type => t)
      end
    end
    create_gem(spec, "#{Pkg::Config.gem_name}-#{Pkg::Config.gemversion}-#{platform}")
  end
end

def package_gem
  unless Pkg::Config.build_gem
    puts "The #{Pkg::Config.project} project does not build any gems! Passing through ..."
    return
  end

  mkdir_p File.join(Pkg::Config.project_root, "pkg")
  create_default_gem
  if Pkg::Config.gem_platform_dependencies
    create_platform_specific_gems
  end
end

namespace :package do
  desc "Build a gem - All gems if platform specific"
  task :gem => ["clean"] do
    package_gem
  end

  task :nightly_gem => ["clean"] do
    Pkg::Config.gemversion = Pkg::Util::Version.extended_dot_version
    package_gem
  end
end

# An alias task to simplify our remote logic in jenkins.rake
namespace :pl do
  task :gem => "package:gem"
  task :nightly_gem => "package:nightly_gem"
end
