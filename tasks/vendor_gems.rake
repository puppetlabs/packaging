namespace :package do
  desc "vendor gems required by project"
  task :vendor_gems do
    sh "bundle install --without development test"
    sh "bundle package"
  end
end
