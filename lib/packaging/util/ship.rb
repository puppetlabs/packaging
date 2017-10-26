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

  def rolling_repo_link_command(platform_tag, repo_path)
    base_path, link_path = Pkg::Paths.artifacts_base_path_and_link_path(platform_tag, repo_path)

    if link_path.nil?
      puts "No link target set, not creating rolling repo link for #{base_path}"
      return nil
    end

    cmd = <<-CMD
      if [ ! -d #{base_path} ] ; then
        echo "Link target '#{base_path}' does not exist; skipping"
        exit 0
      fi
      # If it's a link but pointing to the wrong place, remove the link
      # This is likely to happen around the transition times, like puppet5 -> puppet6
      if [ -L #{link_path} ] && [ ! #{base_path} -ef #{link_path} ] ; then
        rm #{link_path}
      # This is the link you're looking for, nothing to see here
      elif [ -L #{link_path} ] ; then
        exit 0
      # Don't want to delete it if it isn't a link, that could be destructive
      # So, fail!
      elif [ -e #{link_path} ] ; then
        echo "#{link_path} exists but isn't a link, I don't know what to do with this" >&2
        exit 1
      fi
      ln -s #{base_path} #{link_path}
    CMD
  end

  def create_rolling_repo_link(platform_tag, staging_server, repo_path)
    command = rolling_repo_link_command(platform_tag, repo_path)

    Pkg::Util::Net.remote_ssh_cmd(staging_server, command) unless command.nil?
  rescue => e
    fail "Failed to create rolling repo link for '#{platform_tag}'.\n#{e}"
  end

  def test_ship(vm, ship_task)
    command = 'getent group release || groupadd release'
    Pkg::Util::Net.remote_ssh_cmd(vm, command)
    hosts_to_override = %w(
      APT_HOST
      DMG_HOST
      GEM_HOST
      IPS_HOST
      MSI_HOST
      P5P_HOST
      SVR4_HOST
      SWIX_HOST
      TAR_HOST
      YUM_HOST
      APT_SIGNING_SERVER
      APT_STAGING_SERVER
      DMG_STAGING_SERVER
      MSI_STAGING_SERVER
      SWIX_STAGING_SERVER
      TAR_STAGING_SERVER
      YUM_STAGING_SERVER
      STAGING_SERVER
    )
    hosts_to_override.each do |host|
      ENV[host] = vm
    end
    Rake::Task[ship_task].invoke
  end
end
