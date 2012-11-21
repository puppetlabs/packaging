if @build_gem
  require 'rubygems/package_task'

  def glob_gem_files
    gem_files = []
    gem_excludes_file_list = []
    gem_excludes_raw = @gem_excludes.nil? ? [] : @gem_excludes.split(' ')
    gem_excludes_raw << 'ext/packaging'
    gem_excludes_raw.each do |exclude|
      if File.directory?(exclude)
        gem_excludes_file_list += FileList["#{exclude}/**/*"]
      else
        gem_excludes_file_list << exclude
      end
    end
    files = FileList[@gem_files.split(' ')]
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
    s.name = @name                                        unless @name.nil?
    s.name = @gem_name                                    unless @gem_name.nil?
    s.version = @gemversion                               unless @gemversion.nil?
    s.author = @author                                    unless @author.nil?
    s.email = @email                                      unless @email.nil?
    s.homepage = @homepage                                unless @homepage.nil?
    s.summary = @summary                                  unless @summary.nil?
    s.summary = @gem_summary                              unless @gem_summary.nil?
    s.description = @description                          unless @description.nil?
    s.description = @gem_description                      unless @gem_description.nil?
    s.files = glob_gem_files                              unless glob_gem_files.nil?
    s.executables = @gem_executables                      unless @gem_executables.nil?
    s.require_path = @gem_require_path                    unless @gem_require_path.nil?
    s.test_files = FileList[@gem_test_files.split(' ')]   unless @gem_test_files.nil?
    s.rubyforge_project = @gem_forge_project              unless @gem_forge_project.nil?

    @gem_runtime_dependencies.each do |gem, version|
      s.add_runtime_dependency("#{gem}", "#{version}") unless (version.nil? or version.empty?)
      s.add_runtime_dependency("#{gem}") if (version.nil? or version.empty?)
    end unless @gem_runtime_dependencies.nil?

    @gem_devel_dependencies.each do |gem, version|
      s.add_devel_dependency("#{gem}", "#{version}") unless (version.nil? or version.empty?)
      s.add_devel_dependency("#{gem}") if (version.nil? or version.empty?)
    end unless @gem_devel_dependencies.nil?

    @gem_rdoc_options.each do |option|
      s.rdoc_options << option
    end unless @gem_rdoc_options.nil?
  end

  namespace :package do
    gem_task = Gem::PackageTask.new(spec)
    desc "Build a gem"
    task :gem => [ "clean" ] do
      bench = Benchmark.realtime do
        gem_task.define
        Rake::Task[:gem].invoke
        rm_rf "pkg/#{@name}-#{@gemversion}"
      end
      if @benchmark
        add_metrics({ :dist => 'gem', :bench => bench })
        post_metrics
      end
    end
  end
end
