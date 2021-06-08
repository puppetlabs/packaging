
# The pl:fetch task pulls down two files from the build-data repo that contain additional
# data specific to Puppet Labs release infrastructure intended to augment/override any
# defaults specified in the source project repo, e.g. in ext/build_defaults.yaml
#
# It uses curl to download the files, and places them in a temporary
# directory, e.g. /tmp/somedirectory/{project,team}/Pkg::Config.builder_data_file

namespace :pl do
  desc "retrieve build-data configurations to override/extend local build_defaults"
  task :fetch do
    Pkg::Fetch.fetch
    Pkg::Util::RakeUtils.invoke_task('config:validate')
  end
end


