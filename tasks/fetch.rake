# Each team has a build-defaults file that specifies local infrastructure targets
# for things like builders, target locations for build artifacts, etc Since much
# of these don't change, one file can be maintained for the team.  Each project
# also has a data file for information specific to it. If the project builds
# both PE and not PE, it has two files, one for PE, and the other for FOSS
#
data_repo = 'https://raw.githubusercontent.com/puppetlabs/build-data'
if Pkg::Config.dev_build
  puts "NOTICE: This is a dev build!"
  project_data_branch = "#{Pkg::Config.project}-dev"
else
  project_data_branch = Pkg::Config.project
end
team_data_branch = Pkg::Config.team

if Pkg::Config.build_pe
  project_data_branch = 'pe-' + project_data_branch unless project_data_branch =~ /^pe-/
  team_data_branch = 'pe-' + team_data_branch unless team_data_branch =~ /^pe-/
end

project_data_url = data_repo + '/' + project_data_branch
team_data_url = data_repo + '/' + team_data_branch


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
    rm_rf "#{ENV['HOME']}/.packaging" if File.directory?("#{ENV['HOME']}/.packaging")
    # Touch the .packaging file which is allows packaging to present remote tasks
    touch "#{ENV['HOME']}/.packaging"
    [team_data_url, project_data_url].each do |url|
      begin
        tempdir = Pkg::Util::File.mktemp
        %x(curl --fail --silent #{url}/#{Pkg::Config.builder_data_file} > #{tempdir}/#{Pkg::Config.builder_data_file})
        status = $?.exitstatus
        case status
        when 0
          Pkg::Util::RakeUtils.invoke_task("pl:load_extras", tempdir)
        when 22
          if url == team_data_url
            fail "Could not load team extras data from #{url}. This should not normally happen"
          else
            puts "No build data file for #{Pkg::Config.project}, skipping load of extra build data."
          end
        else
          fail "There was an error fetching the builder extras data: #{url}/#{Pkg::Config.builder_data_file} - Exit code #{status}"
        end
      ensure
        rm_rf tempdir
      end
    end
  end
end
