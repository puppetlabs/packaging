# Shipping methods for the older distribution server

module Pkg::Ship::DistributionServer
  class << self

    DS_FILE_OWNER = 'root'
    DS_FILE_GROUP = 'release'

    def ship(local_build_directory, remote_artifacts_directory)
      unless Pkg::Config.project
        fail 'Error: "project" is unset. It must be set in build_defaults.yaml or '\
             'the "PROJECT_OVERRIDE" environment variable.'
      end
      local_artifacts_directory = Pkg::Ship::ArtifactsBundle.create(local_build_directory)
      send_artifacts(local_artifacts_directory, remote_artifacts_directory)
    end

    def send_artifacts(local_artifacts_directory, remote_artifacts_directory)
      distribution_server = Pkg::Config.distribution_server

      # The artifacts will be uploaded to this directory.
      remote_target_directory = File.join(
        Pkg::Config.jenkins_repo_path,
        Pkg::Config.project,
        Pkg::Config.ref,
        remote_artifacts_directory
      )

      Pkg::Util::Net.remote_execute(
        distribution_server,
        "mkdir --mode=775 --parents #{remote_target_directory}"
      )

      Pkg::Util::Execution.retry_on_fail(times: 3) do
        Pkg::Util::Net.rsync_to(
          "#{local_artifacts_directory}/",
          distribution_server, "#{remote_target_directory}/",
          extra_flags: ['--ignore-existing', '--exclude repo_configs']
        )
      end

      # Set the shipped ownership to root/release. Make the files immutable.
      remote_directories = Dir.glob("#{local_artifacts_directory}/**/*")
                             .select { |d| File.directory?(d) }
                             .map { |d| d.sub(local_artifacts_directory, remote_target_directory) }
      Pkg::Util::Net.remote_set_ownership(
        distribution_server, DS_FILE_OWNER, DS_FILE_GROUP, remote_directories
      )
      Pkg::Util::Net.remote_set_permissions(
        distribution_server, '0775', remote_directories)

      remote_files = Dir.glob("#{local_artifacts_directory}/**/*")
                 .select { |f| File.file?(f) }
                 .map { |f| f.sub(local_artifacts_directory, remote_target_directory) }

      # We need to keep <REF>.yaml mutable because it can be updated by multiple processes
      # Yes, this is an ugly race condition.
      immutable_files = remote_files.reject { |f| f.end_with? "#{Pkg::Config.ref}.yaml" }

      Pkg::Util::Net.remote_set_ownership(
        distribution_server, DS_FILE_OWNER, DS_FILE_GROUP, remote_files)
      Pkg::Util::Net.remote_set_permissions(distribution_server, '0664', remote_files)
      Pkg::Util::Net.remote_set_immutable(distribution_server, immutable_files)
    end
  end
end
