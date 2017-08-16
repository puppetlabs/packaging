# Module for shipping all packages to places
require 'tmpdir'
module Pkg::Util::Ship
  module_function

  def collect_packages(pkg_exts, excludes = []) # rubocop:disable Metrics/MethodLength
    pkgs = pkg_exts.map { |ext| Dir.glob(ext) }.flatten
    return [] if pkgs.empty?
    excludes.each do |exclude|
      pkgs.delete_if { |p| p.match(exclude) }
    end if excludes
    if pkgs.empty?
      $stdout.puts "No packages with (#{pkg_exts.join(', ')}) extensions found staged in 'pkg'"
      $stdout.puts "Maybe your excludes argument (#{excludes}) is too restrictive?"
    end
    pkgs
  end

  # Takes a set of packages and reorganizes them into the final repo
  # structure before they are shipping out to their final destination.
  #
  # This assumes the working directory is a temporary directory that will
  # later be cleaned up
  #
  # If this is platform_independent the packages will not get reorganized,
  # just copied under the tmp directory for more consistent workflows
  def reorganize_packages(pkgs, tmp, platform_independent = false)
    new_pkgs = []
    pkgs.each do |pkg|
      if platform_independent
        path = 'pkg'
      else
        platform_tag = Pkg::Paths.tag_from_artifact_path(pkg)
        path = Pkg::Paths.artifacts_path(platform_tag, 'pkg')
      end
      FileUtils.mkdir_p File.join(tmp, path)
      FileUtils.cp pkg, File.join(tmp, path)
      new_pkgs << File.join(path, File.basename(pkg))
    end
    new_pkgs
  end

  # Take local packages and restructure them to the desired final path before
  # shipping to the staging server
  # @param [Array] pkg_exts the file globs for the files you want to ship
  #   For example, something like ['pkg/**/*.rpm', 'pkg/**/*.deb'] to ship
  #   the rpms and debs
  # @param [String] staging_server The hostname to ship the packages to
  # @param [String] remote_path The base path to ship the packages to on the
  #   staging_server, for example '/opt/downloads/windows' or
  #   '/opt/repository/yum'
  # @param [Hash] opts Additional options that can be used when shipping
  #   packages
  # @option opts [Array] :excludes File globs to exclude packages from shipping
  # @option opts [Boolean] :chattr Whether or not to make the files immutable
  #   after shipping. Defaults to true.
  # @option opts [Boolean] :platform_independent Whether or not the path the
  #   packages ship to has platform-dependent information in it. Defaults to
  #   false (most paths will be platform dependent), but set to true for gems
  #   and tarballs since those just land directly under /opt/downloads/<project>
  #
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def ship_pkgs(pkg_exts, staging_server, remote_path, opts = {})
    options = {
      excludes: [],
      chattr: true,
      platform_independent: false }.merge(opts)

    # First find the packages to be shipped. We must find them before moving
    # to our temporary staging directory
    local_packages = collect_packages(pkg_exts, options[:excludes])
    return if local_packages.empty?

    tmpdir = Dir.mktmpdir
    staged_pkgs = reorganize_packages(local_packages, tmpdir, options[:platform_independent])

    puts staged_pkgs.sort
    puts "Do you want to ship the above files to (#{staging_server})?"
    if Pkg::Util.ask_yes_or_no
      extra_flags = ['--ignore-existing', '--delay-updates']
      extra_flags << '--dry-run' if ENV['DRYRUN']

      staged_pkgs.each do |pkg|
        Pkg::Util::Execution.retry_on_fail(times: 3) do
          sub_string = 'pkg'
          remote_pkg = pkg.sub(sub_string, remote_path)
          remote_basepath = File.dirname(remote_pkg)
          Pkg::Util::Net.remote_ssh_cmd(staging_server, "mkdir -p #{remote_basepath}")
          Pkg::Util::Net.rsync_to(
            File.join(tmpdir, pkg),
            staging_server,
            remote_basepath,
            extra_flags: extra_flags
          )

          Pkg::Util::Net.remote_set_ownership(staging_server, 'root', 'release', [remote_pkg])
          Pkg::Util::Net.remote_set_permissions(staging_server, '0664', [remote_pkg])
          Pkg::Util::Net.remote_set_immutable(staging_server, [remote_pkg]) if options[:chattr]
        end
      end
    end
  end
end
