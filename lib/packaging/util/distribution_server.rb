# Utility methods for the older distribution server

require 'fileutils'

module Pkg::Util::DistributionServer
  class << self
    def send_packages(local_source_directory, remote_target_directory)
      Pkg::Util::Execution.retry_on_fail(times: 3) do
        Pkg::Util::Net.remote_execute(
          Pkg::Config.distribution_server,
          "mkdir --mode=775 --parents #{remote_target_directory}"
        )
        Pkg::Util::Net.rsync_to(
          "#{local_source_directory}/",
          Pkg::Config.distribution_server, "#{remote_target_directory}/",
          extra_flags: ['--ignore-existing', '--exclude repo_configs']
        )
      end

      # In order to get a snapshot of what this build looked like at the time
      # of shipping, we also generate and ship the params file
      #
      Pkg::Config.config_to_yaml(local_source_directory)
      Pkg::Util::Execution.retry_on_fail(times: 3) do
        Pkg::Util::Net.rsync_to(
          "#{local_source_directory}/#{Pkg::Config.ref}.yaml",
          Pkg::Config.distribution_server, "#{remote_target_directory}/",
          extra_flags: ["--exclude repo_configs"]
        )
      end

      # If we just shipped a tagged version, we want to make it immutable
      files = Dir.glob("#{local_source_directory}/**/*")
                 .select { |f| File.file?(f) and !f.include? "#{Pkg::Config.ref}.yaml" }
                 .map { |f| "#{remote_target_directory}/#{f.sub(/^#{local_source_directory}\//, '')}" }

      Pkg::Util::Net.remote_set_ownership(Pkg::Config.distribution_server, 'root', 'release', files)
      Pkg::Util::Net.remote_set_permissions(Pkg::Config.distribution_server, '0664', files)
      Pkg::Util::Net.remote_set_immutable(Pkg::Config.distribution_server, files)
    end
  end
end
