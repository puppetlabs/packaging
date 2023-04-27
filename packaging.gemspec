require 'time'

Gem::Specification.new do |gem|
  gem.name    = 'packaging'
  gem.version = %x(git describe --tags).gsub('-', '.').chomp
  gem.date    = Date.today.to_s

  gem.summary = 'Puppet by Perforce packaging automation'
  gem.description = 'Packaging automation for Puppet FOSS projects'
  gem.license = "Apache-2.0"

  gem.authors  = ['Puppet By Perforce']
  gem.email    = 'release@puppet.com'
  gem.homepage = 'http://github.com/puppetlabs/packaging'

  gem.required_ruby_version = '>= 2.3.0'

  gem.add_development_dependency('debug', '>= 1.0.0')
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('rubocop')

  gem.add_runtime_dependency('artifactory', ['~> 3'])
  gem.add_runtime_dependency('csv', ['>= 3.1.5'])
  gem.add_runtime_dependency('googleauth')
  gem.add_runtime_dependency('google-cloud-storage')
  gem.add_runtime_dependency('rake', ['>= 12.3'])
  gem.add_runtime_dependency('release-metrics')

  gem.require_path = 'lib'

  # Ensure the gem is built out of versioned files
  gem.files = Dir['{lib,spec,static_artifacts,tasks,templates}/**/*', 'README*', 'LICENSE*'] & %x(git ls-files -z).split("\0")
  gem.test_files = Dir['spec/**/*_spec.rb']
end
