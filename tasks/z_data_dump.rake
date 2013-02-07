##
# These tasks are just wrappers for the build objects capabilities, exposed
# for our debugging purposes. This file is prepended with `z_` to ensure it is
# loaded last, so that any variable manipulations that occur in the rake tasks
# happen prior to printing (although ideally all variables have been set after
# loading `20_setupextrasvars.rake`).
#
namespace :pl do
  ##
  # Utility rake task that will dump all current build parameters and variables
  # to a yaml file to a temporary location and print the path. Given the
  # environment variable 'OUTPUT_DIR', output file at 'OUTPUT_DIR'. The
  # environment variable TASK sets the task instance variable of the build to the
  # supplied args, allowing us to use this file for later builds.
  #
  desc "Write all package build parameters to a yaml file, pass OUTPUT_DIR to specify outut location"
  task :write_build_params do
    if ENV['TASK']
      @build.task = ENV['TASK'].split(' ')
    end
    @build.params_to_yaml(ENV['OUTPUT_DIR'])
  end

  ##
  # Print all build parameters to STDOUT.
  #
  desc "Print all package build parameters"
  task :print_build_params do
    @build.print_params
  end
end

