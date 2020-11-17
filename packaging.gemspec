require 'time'

Gem::Specification.new do |gem|
  gem.name    = 'packaging'
  gem.version = %x(git describe --tags).gsub('-', '.').chomp
  gem.date    = Date.today.to_s

  gem.summary = "Puppet Labs' packaging automation"
  gem.description = "Packaging automation written in Rake and Ruby. Easily build native packages for most platforms with a few data files and git."
  gem.license = "Apache-2.0"

  gem.authors  = ['Puppet Labs']
  gem.email    = 'info@puppetlabs.com'
  gem.homepage = 'http://github.com/puppetlabs/packaging'

  gem.required_ruby_version = '>= 2.0.0'

  gem.add_development_dependency('rspec', ['~> 2.14.1'])
  gem.add_development_dependency('rubocop', ['~> 0.24.1'])
  gem.add_development_dependency('pry-byebug')
  gem.add_runtime_dependency('rake', ['>= 12.3'])
  gem.add_runtime_dependency('artifactory', ['~> 2'])
  gem.add_runtime_dependency('release-metrics')
  gem.add_runtime_dependency('csv', ['3.1.5'])
  gem.require_path = 'lib'

  # Ensure the gem is built out of versioned files
  gem.files = Dir['{lib,spec,static_artifacts,tasks,templates}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z`.split("\0")
  gem.test_files = Dir['spec/**/*_spec.rb']
end
