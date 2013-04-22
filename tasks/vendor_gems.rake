# This is an optional pre-tar-task, so we only want to present it if we're
# using it
if @build.pre_tar_task = "package:vendor_gems"
  namespace :package do
    desc "vendor gems required by project"
    task :vendor_gems do
      sh "bundle install --without development test"
      sh "bundle package"
    end
  end
end
