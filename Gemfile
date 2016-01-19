source "https://rubygems.org"

group :development, :test do
  gem 'rake', "~> 0.9.6"
  gem 'rspec', "~> 2.14.1"
  gem 'pry'
  gem 'win32console', :platforms => [:mingw_18, :mingw_19]
  gem 'rubocop', "~> 0.24.1", :require => false
end

group :jira do
  # After 0.1.12 the jira-ruby gem depends on the latest activesupport,
  # which in turn requires ruby >= 2.2.2. So until we move to ruby 2.2,
  # lock the version of jira-ruby to 0.1.12:
  gem 'jira-ruby', "0.1.12"
end
