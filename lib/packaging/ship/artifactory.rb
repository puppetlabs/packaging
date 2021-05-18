# Utility methods for shipping to Artifactory

module Pkg::Ship::Artifactory
  class << self
    def ship(local_build_directory, remote_artifacts_directory)
      unless Pkg::Config.project
        fail 'Error: "project" is unset. It must be set in build_defaults.yaml or '\
             'the "PROJECT_OVERRIDE" environment variable.'
      end

      artifactory = Pkg::ManageArtifactory.new(Pkg::Config.project, Pkg::Config.ref)
      local_artifacts_directory = Pkg::Ship::ArtifactsBundle.create(local_build_directory)

      ref_yaml_file = Pkg::Config.config_to_yaml(local_artifacts_directory)

      # This is a hack.
      # There are a few bugs and a race-condition here. We've modified the <REF>.yaml file in
      # the artifacts directory with Artifactory-specific details but now we
      # keep the distribution server in-sync so that we don't get diverging data.
      # We need to:
      #   remove this race condition
      #   move the platform_data insertion out of Artifactory-specific code.
      #   make platform_data live alongside (or inside) the platform-specific json, rather than
      #     in REF.yaml
      remote_ref_yaml_directory = File.join(
        Pkg::Config.jenkins_repo_path,
        Pkg::Config.project,
        Pkg::Config.ref,
        remote_artifacts_directory
      )
      Pkg::Util::Net.rsync_to(
        ref_yaml_file,
        Pkg::Config.distribution_server,
        "#{remote_ref_yaml_directory}/#{File.basename(ref_yaml_file)}",
        extra_flags: []
      )

      # Now back to our Artifactory-specific work
      artifacts_tarball = Pkg::Ship::ArtifactsBundle.artifacts_tarball_name
      File.delete(artifacts_tarball) if File.exist?(artifacts_tarball)

      # Acquire a list of packages already on Artifactory and refuse to upload them.
      # This is a rough, cheap version of the 'chattr' approach on the distribution server.
      # Like that we'll still allow overwriting of yaml and json files.
      permitted_files = overwrite_guardian(artifactory, local_artifacts_directory)
      artifacts_tarball = Pkg::Ship::ArtifactsBundle.create_tarball(
        local_artifacts_directory, permitted_files)
      artifactory.deploy_archive(artifacts_tarball)
    end

    # Scan through artifacts_directory and look for artifacts that already exist.
    # Exempt .json and .yaml files.
    # Return a list of allowable uploads
    def overwrite_guardian(artifactory, artifacts_directory)
      Dir.chdir(artifacts_directory) do
        Dir['**/*'].select do |path|
          if !File.file?(path)
            false
          elsif path.end_with?('.yaml', '.json')
            true
          elsif artifactory.artifact_exist?(path)
            false
          else
            true
          end
        end
      end
    end
  end
end
