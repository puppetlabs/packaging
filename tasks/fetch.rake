require 'packaging'

# Each team has a build-defaults file that specifies local infrastructure targets
# for things like builders, target locations for build artifacts, etc Since much
# of these don't change, one file can be maintained for the team.  Each project
# also has a data file for information specific to it. If the project builds
# both PE and not PE, it has two files, one for PE, and the other for FOSS

# The pl:fetch task pulls down two files from the build-data repo that contain additional
# data specific to Puppet Labs release infrastructure intended to augment/override any
# defaults specified in the source project repo, e.g. in ext/build_defaults.yaml
#
# It uses curl to download the files, and places them in a temporary
# directory, e.g. /tmp/somedirectory/{project,team}/Pkg::Config.builder_data_file
namespace :pl do
  desc "retrieve build-data configurations to override/extend local build_defaults"
  task :fetch do

    # Remove .packaging directory from old-style extras loading
    Pkg::Config::BuildParams.cleanup

    # Touch the .packaging file which is allows packaging to present remote tasks
    Pkg::Config::BuildParams.present

    # Get the things
    Pkg::Config::BuildParams.retrieve

    # Environment variables take precedence over those loaded from configs,
    # so we make sure that any we clobbered are reset.
    Pkg::Config.load_envvars
  end
end
