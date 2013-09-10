# Each team has a build-defaults file that specifies local infrastructure targets
# for things like builders, target locations for build artifacts, etc Since much
# of these don't change, one file can be maintained for the team.  Each project
# also has a data file for information specific to it. If the project builds
# both PE and not PE, it has two files, one for PE, and the other for FOSS
#
data_repo = 'https://raw.github.com/puppetlabs/build-data'
project_data_branch = @build.project
team_data_branch = @build.team

if @build.build_pe
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
# directory, e.g. /tmp/somedirectory/{project,team}/@build.builder_data_file
namespace :pl do
  task :fetch do
    # Remove .packaging directory from old-style extras loading
    rm_rf "#{ENV['HOME']}/.packaging" if File.directory?("#{ENV['HOME']}/.packaging")
    # Touch the .packaging file which is allows packaging to present remote tasks
    touch "#{ENV['HOME']}/.packaging"
    if dist = el_version
      if dist.to_i < 6
        flag = "-k"
      end
    end
    [project_data_url, team_data_url].each do |url|
      begin
        tempdir = get_temp
        %x{curl --fail --silent #{flag} #{url}/#{@build.builder_data_file} > #{tempdir}/#{@build.builder_data_file}}
        case $?.exitstatus
        when 0
          invoke_task("pl:load_extras", tempdir)
        when 22
          if url == team_data_url
            fail "Could not load team extras data from #{url}. This should not normally happen"
          else
            puts "No build data file for #{@build.project}, skipping load of extra build data."
          end
        else
          fail "There was an error fetching the builder extras data from #{url}."
        end
      ensure
        rm_rf tempdir
      end
    end
  end
end
