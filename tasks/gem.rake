if @build.build_gem
  require 'rubygems/package_task'

  def glob_gem_files
    gem_files = []
    gem_excludes_file_list = []
    gem_excludes_raw = @build.gem_excludes.nil? ? [] : @build.gem_excludes.split(' ')
    gem_excludes_raw << 'ext/packaging'
    gem_excludes_raw.each do |exclude|
      if File.directory?(exclude)
        gem_excludes_file_list += FileList["#{exclude}/**/*"]
      else
        gem_excludes_file_list << exclude
      end
    end
    files = FileList[@build.gem_files.split(' ')]
    files.each do |file|
      if File.directory?(file)
        gem_files += FileList["#{file}/**/*"]
      else
        gem_files << file
      end
    end
    gem_files = gem_files - gem_excludes_file_list
  end

  spec = Gem::Specification.new do |s|
    s.name = @build.project                                     unless @build.project.nil?
    s.name = @build.gem_name                                    unless @build.gem_name.nil?
    s.version = @build.gemversion                               unless @build.gemversion.nil?
    s.author = @build.author                                    unless @build.author.nil?
    s.email = @build.email                                      unless @build.email.nil?
    s.homepage = @build.homepage                                unless @build.homepage.nil?
    s.summary = @build.summary                                  unless @build.summary.nil?
    s.summary = @build.gem_summary                              unless @build.gem_summary.nil?
    s.description = @build.description                          unless @build.description.nil?
    s.description = @build.gem_description                      unless @build.gem_description.nil?
    s.files = glob_gem_files                                    unless glob_gem_files.nil?
    s.executables = @build.gem_executables                      unless @build.gem_executables.nil?
    s.require_path = @build.gem_require_path                    unless @build.gem_require_path.nil?
    s.test_files = FileList[@build.gem_test_files.split(' ')]   unless @build.gem_test_files.nil?
    s.rubyforge_project = @build.gem_forge_project              unless @build.gem_forge_project.nil?

    @build.gem_runtime_dependencies.each do |gem, version|
      s.add_runtime_dependency("#{gem}", "#{version}") unless (version.nil? or version.empty?)
      s.add_runtime_dependency("#{gem}") if (version.nil? or version.empty?)
    end unless @build.gem_runtime_dependencies.nil?

    @build.gem_devel_dependencies.each do |gem, version|
      s.add_devel_dependency("#{gem}", "#{version}") unless (version.nil? or version.empty?)
      s.add_devel_dependency("#{gem}") if (version.nil? or version.empty?)
    end unless @build.gem_devel_dependencies.nil?

    @build.gem_rdoc_options.each do |option|
      s.rdoc_options << option
    end unless @build.gem_rdoc_options.nil?
  end

  namespace :package do
    gem_task = Gem::PackageTask.new(spec)
    desc "Build a gem"
    manageable_task :gem => [ "clean" ] do
      bench = Benchmark.realtime do
        gem_task.define
        Rake::Task[:gem].invoke
        rm_rf "pkg/#{@build.project}-#{@build.gemversion}"
      end
      if @build.benchmark
        add_metrics({ :dist => 'gem', :bench => bench })
        post_metrics
      end
    end
  end

  # An alias task to simplify our remote logic in jenkins.rake
  namespace :pl do
    task :gem => "package:gem"
  end
end
