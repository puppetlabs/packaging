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
      task_args = ENV['TASK'].split(' ')
      Pkg::Config.task = { :task => task_args[0], :args => task_args[1..-1] }
    end
    Pkg::Config.config_to_yaml(ENV['OUTPUT_DIR'])
  end

  ##
  # Print all build parameters to $stdout.
  #
  desc "Print all package build parameters"
  task :print_build_params do
    Pkg::Config.print_config
  end

  ##
  # Print a parameter passed as an argument to $stdout.
  desc "Print a build parameter"
  task :print_build_param, :param do |t, args|
    # We want a string that is the from "@<param name>"
    if param = args.param
      getter = param.dup
      case param[0]
      when ':'
        getter = param[1..-1]
        param[0] = "@"
      when "@"
        getter = param[1..-1]
      else
        param.insert(0, "@")
      end

      # We want to fail if the param passed is bogus, print 'nil' if its not
      # set, and print the value if its set.
      if Pkg::Config.respond_to?(getter)
        if val = Pkg::Config.instance_variable_get(param)
          puts val
        else
          puts 'nil'
        end
      else
        fail "Could not locate a build parameter called #{param}. For a list of available parameters, do `rake pl:print_build_params`"
      end
    else
      fail "To print a build parameter, pass the param name as a rake argument. Ex: rake pl:print_build_param[:version]"
    end
  end
end
