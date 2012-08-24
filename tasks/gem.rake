if @build_gem == TRUE or @build_gem == 'true' or @build_gem == 'TRUE'
  require 'rubygems/package_task'

  spec = Gem::Specification.new do |s|
    s.name = @name
    s.version = @version
    s.author = @author
    s.email = @email
    s.homepage = @homepage
    s.summary = @summary
    s.description = @description
    s.files = FileList[@gem_files.split(' ')]
    s.require_path = @gem_require_path
    s.test_files = FileList[@gem_test_files.split(' ')]
    s.executables = @gem_executables
    s.rubyforge_project = @gem_forge_project

    @gem_dependencies.each do |key, value|
      s.add_dependency("#{key}", "#{value}")
    end unless @gem_dependencies.nil?

    @gem_rdoc_options.each do |option|
      s.rdoc_options << option
    end unless @gem_rdoc_options.nil?
  end

  namespace :package do
    Gem::PackageTask.new(spec) do |pkg|
      pkg.need_tar_gz = true
    end
  end
end

