# This is an optional pre-tar-task, so we only want to present it if we're
# using it
if @build.pre_tar_task == "package:vendor_gems"
  namespace :package do
    desc "vendor gems required by project"
    task :vendor_gems do
      check_tool("bundle")
      require 'bundler'
      require 'rubygems'
      require 'rubygems/gem_runner'

      without = [:development, :test]

      runner = Gem::GemRunner.new
      definition = Bundler::Definition.build('Gemfile', 'Gemfile.lock', nil)
      resolver = definition.resolve

      lazy_specs = resolver.for(definition.dependencies.reject {|d| (d.groups - without).empty?}, [], false, true).to_a.uniq

      mkdir_p 'vendor/cache'
      cd 'vendor/cache'

      lazy_specs.each do |spec|
        runner.run ['fetch', spec.name, '-v', spec.version.to_s]
      end
    end
  end
end
