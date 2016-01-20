source 'https://rubygems.org'

group :development, :test do
  gem 'rake', '~> 0.9.6'
  gem 'rspec', '~> 2.14.1'
  gem 'pry'
  gem 'win32console', platforms: [:mingw_18, :mingw_19]
  gem 'rubocop', '~> 0.24.1', require: false
end

group :jira do
  # The latest versions of ActiveSupport require Ruby 2.2 or greater.
  # Instead of forcing a Ruby upgrade, we should constrain the version
  # of ActiveSupport to anything less than 5.0.0, where the requirement
  # was introduced. I mean, we could probably constrain this in general
  # because ActiveSupport is not a thing we want to rely on, but
  # being conservative is probably safest.
  #
  # - Ryan McKern, 2016-01-19
  if RUBY_REVISION < 50295
    gem 'activesupport', '< 5.0.0', require: false
  end
  gem 'jira-ruby'
end
