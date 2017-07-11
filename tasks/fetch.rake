# Each team has a build-defaults file that specifies local infrastructure targets
# for things like builders, target locations for build artifacts, etc Since much
# of these don't change, one file can be maintained for the team.  Each project
# also has a data file for information specific to it. If the project builds
# both PE and not PE, it has two files, one for PE, and the other for FOSS
#
data_repo = Pkg::Config.build_data_repo

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

    begin
      temp_build_data_dir = Pkg::Util::File.mktemp
      %x(git clone --depth 1 #{data_repo} #{temp_build_data_dir})
      case $?.success
      when 0
        Dir.chdir(temp_build_data_dir) do
          [team_data_branch, project_data_branch].each do |branch|
            %x(git checkout #{branch})
            case $?.success
            when 0
              Pkg::Util::RakeUtils.invoke_task("pl:load_extras", temp_build_data_dir)
            else
              warn "Unable to load build_defaults from branch '#{branch}' in '#{data_repo}'. Skipping."
            end
          end
        end
      else
        fail "There was an error attempting to fetch the build-data repo. Maybe you do not have the correct permissions?"
      end
    ensure
      rm_rf temp_build_data_dir
    end
  end
end
