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
      @build.gem_rdoc_options.each do |option|
        s.rdoc_options << option
      end unless @build.gem_rdoc_options.nil?
    end

    @build.gem_runtime_dependencies.each do |gem, version|
      spec = add_gem_dependency(:spec => spec, :gem => gem, :version => version, :type => :runtime)
    end unless @build.gem_runtime_dependencies.nil?

    @build.gem_development_dependencies.each do |gem, version|
      spec = add_gem_dependency(:spec => spec, :gem => gem, :version => version, :type => :development)
    end unless @build.gem_development_dependencies.nil?
    spec
  end

  def create_gem(spec, gembuilddir)
    gem_task = Gem::PackageTask.new(spec)
    bench = Benchmark.realtime do
      gem_task.define
      Rake::Task[:gem].reenable
      Rake::Task[:gem].invoke
      rm_rf File.join("pkg", gembuilddir)
    end
    puts "Finished building in: #{bench}"
  end

  def create_default_gem
    spec = create_default_gem_spec
    create_gem(spec, "#{@build.project}-#{@build.gemversion}")
  end

  def unknown_gems_platform?(platform)
    return true if platform.os == "unknown"
    false
  end

  def create_platform_specific_gems
    @build.gem_platform_dependencies.each do |platform, dependency_hash|
      spec = create_default_gem_spec
      pf = Gem::Platform.new(platform)
      fail "
        Platform: '#{platform}' is not recognized by rubygems.
        This is probably an erroneous 'gem_platform_dependencies' entry!" if unknown_gems_platform?(pf)
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
      create_gem(spec, "#{@build.project}-#{@build.gemversion}-#{platform}")
    end
  end

  namespace :package do
    desc "Build a gem - All gems if platform specific"
    task :gem => [ "clean" ] do
      create_default_gem
      if @build.gem_platform_dependencies
        create_platform_specific_gems
      end
    end
  end

  # An alias task to simplify our remote logic in jenkins.rake
  namespace :pl do
    task :gem => "package:gem"
  end
end
