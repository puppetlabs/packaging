# Perform a build exclusively from a build params file. Requires that the build
# params file include a setting for task, which is an array of the arguments
# given to rake originally, including, first, the task name. The params file is
# always loaded when passed, so these variables are accessible immediately.
namespace :pl do
  desc "Build from a build params file"
  task :build_from_params do
    Pkg::Util.check_var('PARAMS_FILE', ENV['PARAMS_FILE'])
    Pkg::Util::Version.git_co(Pkg::Config.ref)
    Rake::Task[Pkg::Config.task[:task]].invoke(Pkg::Config.task[:args])
  end
end
