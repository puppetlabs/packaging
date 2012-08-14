spec = Gem::Specification.new do |s|
  s.name = @name
  s.version = @version
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

