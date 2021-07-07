# Shipping methods for creating an artifact bundle

require 'fileutils'

##
## Some definitions:
##
## build directory: the files generated from project build. Typically, DEBs, RPMs, MSIs,
## tarballs, etc. It can contain files from multiple components and multiple platforms.
##
## artifacts directory: a vetted copy of the build directory often with added metadata
## and support files such as signing and packaging bundles.
##

module Pkg::Ship::ArtifactsBundle
  class << self
    def create(build_directory, artifacts_directory = 'artifacts')

      # If the artifacts directory exists, don't rebuild it.
      if Dir.exist?(artifacts_directory)
        puts "Info: '#{artifacts_directory}' directory exists. Not rebuilding it."
        return artifacts_directory
      end

      # Hardlinks are great when you can get them
      if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.6.0')
        FileUtils.cp_lr(build_directory, artifacts_directory)
      else
        FileUtils.cp_r(build_directory, artifacts_directory)
      end

      # For EZBake builds, we also want to include the ezbake.manifest file to
      # get a snapshot of this build and all dependencies. We eventually will
      # create a yaml version of this file, but until that point we want to
      # make the original ezbake.manifest available
      Pkg::Ship::EZbake.add_manifest(artifacts_directory)

      # Inside build_metadata*.json files there is additional metadata containing
      # information such as git ref and dependencies that are needed at build
      # time. If these files exist, copy them downstream.
      # Typically these files are named 'ext/build_metadata.<project>.<platform>.json'
      Pkg::Ship::BuildMetadata.add_misc_json_files(artifacts_directory)

      # Sadly, the packaging repo cannot yet act on its own, without living
      # inside of a packaging-repo compatible project. This means in order to
      # use the packaging repo for shipping and signing (things that really
      # don't require build automation, specifically) we still need the project
      # clone itself.
      Pkg::Util::Git.bundle('HEAD', 'signing_bundle', artifacts_directory)

      # While we're bundling things, let's also make a git bundle of the
      # packaging repo that we're using when we invoke pl:jenkins:ship. We can
      # have a reasonable level of confidence, later on, that the git bundle on
      # the distribution server was, in fact, the git bundle used to create the
      # associated packages. This is because this ship task is automatically
      # called upon completion each cell of the pl:jenkins:uber_build, and we
      # have --ignore-existing set below. As such, the only git bundle that
      # should possibly be on the distribution is the one used to create the
      # packages.
      # We're bundling the packaging repo because it allows us to keep an
      # archive of the packaging source that was used to create the packages,
      # so that later on if we need to rebuild an older package to audit it or
      # for some other reason we're assured that the new package isn't
      # different by virtue of the packaging automation.
      if defined?(PACKAGING_ROOT)
        packaging_bundle = Dir.chdir(PACKAGING_ROOT) do
          Pkg::Util::Git.bundle('HEAD', 'packaging-bundle')
        end
        mv(packaging_bundle, artifacts_directory)
      end

      # This is functionality to add the project-arch.msi links that have no
      # version. The code itself looks for the link (if it's there already)
      # and if the source package exists before linking. Searching for the
      # packages has been restricted specifically to just the pkg/windows dir
      # on purpose, as this is where we currently have all windows packages
      # building to.
      Pkg::Ship::Windows.add_msi_links(artifacts_directory)

      return artifacts_directory
    end

    def create_tarball(artifacts_directory, permitted_files)
      tar_command = Pkg::Util::Tool.find_tool('tar')

      files_for_tar_command = permitted_files.map { |file| "\"#{file}\"" }.join(' ')
      create_tarball_command = %W(
        #{tar_command} -C #{artifacts_directory} -czf #{artifacts_tarball_name}
        #{files_for_tar_command}
      ).join(' ')

      # Create a tarball of the artifacts directory. This can be uploaded to
      # remote servers but is the easiest way to upload to Artifactory
      Pkg::Util::Execution.capture3(create_tarball_command, true)

      return artifacts_tarball_name
    end

    def artifacts_tarball_name
      "artifacts.#{Pkg::Config.ref}.tgz"
    end

    def artifacts_tarball_exist?
      return artifacts_tarball_name if File.readable?(artifacts_tarball_name)
      return false
    end
  end
end
