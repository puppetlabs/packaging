##
# An alias from pe:tar to package:tar, for easier automation in jenkins.rake
namespace :pe do
  task :local_tar => ["package:tar"]
end
