module Pkg
  class Fetch
    class << self
      def fetch
        packaging_dot_file = "#{ENV['HOME']}/.packaging"
        data_repo = Pkg::Config.build_data_repo

        # Each team has a build-defaults file that specifies local infrastructure targets
        # for things like builders, target locations for build artifacts, etc Since much
        # of these don't change, one file can be maintained for the team.  Each project
        # also has a data file for information specific to it. If the project builds
        # both PE and not PE, it has two files, one for PE, and the other for FOSS

        team_data_branch = Pkg::Config.team
        project_data_branch = Pkg::Config.project
        if Pkg::Config.dev_build
          puts "Info: This is a dev build."
          project_data_branch = "#{Pkg::Config.project}-dev"
        end

        if Pkg::Config.build_pe
          project_data_branch = 'pe-' + project_data_branch unless project_data_branch =~ /^pe-/
          team_data_branch = 'pe-' + team_data_branch unless team_data_branch =~ /^pe-/
        end

        # Remove .packaging directory from old-style extras loading
        FileUtils.rm_rf packaging_dot_file if File.directory? packaging_dot_file

        # Touch the .packaging file which is allows packaging to present remote tasks
        FileUtils.touch packaging_dot_file

        build_data_directory = Pkg::Util::File.mktemp
        %x(git clone #{data_repo} #{build_data_directory})
        unless $?.success?
          fail 'Error: could not fetch the build-data repo. Are permissions correct?'
        end
        
        Dir.chdir(build_data_directory) do
          [team_data_branch, project_data_branch].each do |branch|
            %x(git checkout #{branch})
            unless $?.success?
              warn "Warning: no build_defaults found in branch '#{branch}' of '#{data_repo}'. " \
                   "Skipping."
              next
            end
            load_extras(build_data_directory)
          end
        end
      ensure
        FileUtils.rm_rf build_data_directory
      end

      def load_extras(build_data_directory)
        # Don't do this if the user has provided a non-standard PARAMS_FILE
        return unless ENV['PARAMS_FILE'].to_s.empty?

        unless File.directory? build_data_directory
          raise "Error: load_extras requires a directory containing extras data."
        end
        Pkg::Config.config_from_yaml(File.join(build_data_directory, Pkg::Config.builder_data_file))

        # Environment variables take precedence over those loaded from configs,
        # so we make sure that any we clobbered are reset.
        Pkg::Config.load_envvars
      end
    end
  end
end
