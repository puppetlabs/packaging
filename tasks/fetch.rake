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
    tempdir = get_temp
    mkdir_pr("#{tempdir}/team", "#{tempdir}/project")
    begin
      if dist = el_version
        if dist.to_i < 6
          flag = "-k"
        end
      end
      sh "curl #{flag} #{project_data_url}/#{@build.builder_data_file} > #{tempdir}/project/#{@build.builder_data_file}"
      sh "curl #{flag} #{team_data_url}/#{@build.builder_data_file} > #{tempdir}/team/#{@build.builder_data_file}"
      invoke_task("pl:load_extras", tempdir)
      rm_rf(tempdir)
    rescue
      STDERR.puts "There was an error fetching the builder extras data."
      exit 1
    end
  end
end
