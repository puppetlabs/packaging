# Each team has a build-defaults file that specifies local infrastructure targets
# for things like builders, target locations for build artifacts, etc Since much
# of these don't change, one file can be maintained for the team.  Each project
# also has a data file for information specific to it. If the project builds
# both PE and not PE, it has two files, one for PE, and the other for FOSS
#
data_repo = 'https://raw.github.com/puppetlabs/build-data'
project_data_branch = @project
team_data_branch = @team

if @build_pe
  project_data_branch = 'pe-' + project_data_branch unless project_data_branch =~ /^pe-/
  team_data_branch = 'pe-' + team_data_branch unless team_data_branch =~ /^pe-/
end

project_data_url = data_repo + '/' + project_data_branch
team_data_url = data_repo + '/' + team_data_branch


# The pl:fetch task pulls down a file from the build-data repo that contains additional
# data specific to Puppet Labs release infrastructure intended to augment/override any
# defaults specified in the source project repo, e.g. in ext/build_defaults.yaml
#
# It uses curl to download the file, and places it in a hidden directory in the home
# directory, e.g. ~/.packaging/@builder_data_file
namespace :pl do
  task :fetch do
    rm_rf "#{ENV['HOME']}/.packaging"
    mkdir_pr("#{ENV['HOME']}/.packaging/team", "#{ENV['HOME']}/.packaging/project")
    begin
      if dist = el_version
        if dist.to_i < 6
          flag = "-k"
        end
      end
      sh "curl #{flag} #{project_data_url}/#{@builder_data_file} > #{ENV['HOME']}/.packaging/project/#{@builder_data_file}"
      sh "curl #{flag} #{team_data_url}/#{@builder_data_file} > #{ENV['HOME']}/.packaging/team/#{@builder_data_file}"
    rescue
      STDERR.puts "There was an error fetching the builder extras data."
      exit 1
    end
  end
end
