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
  def reorganize_packages(pkgs, tmp, platform_independent = false, nonfinal = false)
    new_pkgs = []
    pkgs.each do |pkg|
      if platform_independent
        path = 'pkg'
      else
        platform_tag = Pkg::Paths.tag_from_artifact_path(pkg)
        path = Pkg::Paths.artifacts_path(platform_tag, 'pkg', nonfinal)
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
      platform_independent: false,
      nonfinal: false }.merge(opts)

    # First find the packages to be shipped. We must find them before moving
    # to our temporary staging directory
    local_packages = collect_packages(pkg_exts, options[:excludes])
    return false if local_packages.empty?

    tmpdir = Dir.mktmpdir
    staged_pkgs = reorganize_packages(local_packages, tmpdir, options[:platform_independent], options[:nonfinal])

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
          Pkg::Util::Net.remote_execute(staging_server, "mkdir -p #{remote_basepath}")
          Pkg::Util::Net.rsync_to(
            File.join(tmpdir, pkg),
            staging_server,
            remote_basepath,
            extra_flags: extra_flags
          )

          Pkg::Util::Net.remote_set_ownership(staging_server, 'root', 'release', [remote_basepath, remote_pkg])
          Pkg::Util::Net.remote_set_permissions(staging_server, '775', [remote_basepath])
          Pkg::Util::Net.remote_set_permissions(staging_server, '0664', [remote_pkg])
          Pkg::Util::Net.remote_set_immutable(staging_server, [remote_pkg]) if options[:chattr]
        end
      end
      return true
    end
  end

  def ship_rpms(local_staging_directory, remote_path, opts = {})
    things_to_ship = [
      "#{local_staging_directory}/**/*.rpm",
      "#{local_staging_directory}/**/*.srpm"
    ]
    ship_pkgs(things_to_ship, Pkg::Config.yum_staging_server, remote_path, opts)
  end

  def ship_debs(local_staging_directory, remote_path, opts = {})
    things_to_ship = [
      "#{local_staging_directory}/**/*.debian.tar.gz",
      "#{local_staging_directory}/**/*.orig.tar.gz",
      "#{local_staging_directory}/**/*.dsc",
      "#{local_staging_directory}/**/*.deb",
      "#{local_staging_directory}/**/*.changes"
    ]
    ship_pkgs(things_to_ship, Pkg::Config.apt_signing_server, remote_path, opts)
  end

  def ship_svr4(local_staging_directory, remote_path, opts = {})
    ship_pkgs(["#{local_staging_directory}/**/*.pkg.gz"], Pkg::Config.svr4_host, remote_path, opts)
  end

  def ship_p5p(local_staging_directory, remote_path, opts = {})
    ship_pkgs(["#{local_staging_directory}/**/*.p5p"], Pkg::Config.p5p_host, remote_path, opts)
  end

  def ship_dmg(local_staging_directory, remote_path, opts = {})
    packages_have_shipped = ship_pkgs(["#{local_staging_directory}/**/*.dmg"],
                                      Pkg::Config.dmg_staging_server, remote_path, opts)

    if packages_have_shipped
      Pkg::Platforms.platform_tags_for_package_format('dmg').each do |platform_tag|
        # Create the latest symlink for the current supported repo
        Pkg::Util::Net.remote_create_latest_symlink(
          Pkg::Config.project,
          Pkg::Paths.artifacts_path(platform_tag, remote_path, opts[:nonfinal]),
          'dmg'
        )
      end
    end
  end

  def ship_swix(local_staging_directory, remote_path, opts = {})
    ship_pkgs(["#{local_staging_directory}/**/*.swix"], Pkg::Config.swix_staging_server, remote_path, opts)
  end

  def ship_msi(local_staging_directory, remote_path, opts = {})
    packages_have_shipped = ship_pkgs(["#{local_staging_directory}/**/*.msi"], Pkg::Config.msi_staging_server, remote_path, opts)

    if packages_have_shipped
      # Create the symlinks for the latest supported repo
      Pkg::Util::Net.remote_create_latest_symlink(Pkg::Config.project, Pkg::Paths.artifacts_path(Pkg::Platforms.generic_platform_tag('windows'), remote_path, opts[:nonfinal]), 'msi', arch: 'x64')
      Pkg::Util::Net.remote_create_latest_symlink(Pkg::Config.project, Pkg::Paths.artifacts_path(Pkg::Platforms.generic_platform_tag('windows'), remote_path, opts[:nonfinal]), 'msi', arch: 'x86')
    end
  end

  def ship_gem(local_staging_directory, remote_path, opts = {})
    ship_pkgs(["#{local_staging_directory}/*.gem*"], Pkg::Config.gem_host, remote_path, opts)
  end

  def ship_tar(local_staging_directory, remote_path, opts = {})
    ship_pkgs(["#{local_staging_directory}/*.tar.gz*"], Pkg::Config.tar_staging_server, remote_path, opts)
  end

  def rolling_repo_link_command(platform_tag, repo_path, nonfinal = false)
    base_path, link_path = Pkg::Paths.artifacts_base_path_and_link_path(platform_tag, repo_path, nonfinal)

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

  def create_rolling_repo_link(platform_tag, staging_server, repo_path, nonfinal = false)
    command = rolling_repo_link_command(platform_tag, repo_path, nonfinal)

    Pkg::Util::Net.remote_execute(staging_server, command) unless command.nil?
  rescue => e
    fail "Failed to create rolling repo link for '#{platform_tag}'.\n#{e}\n#{e.backtrace}"
  end

  # create all of the rolling repo links in one step
  def create_rolling_repo_links(nonfinal = false)
    yum_path = Pkg::Paths.remote_repo_base(nonfinal: nonfinal, package_format: 'rpm')
    dmg_path = Pkg::Paths.remote_repo_base(nonfinal: nonfinal, package_format: 'dmg')
    swix_path = Pkg::Paths.remote_repo_base(nonfinal: nonfinal, package_format: 'swix')
    msi_path = Pkg::Paths.remote_repo_base(nonfinal: nonfinal, package_format: 'msi')

    create_rolling_repo_link(Pkg::Platforms.generic_platform_tag('el'), Pkg::Config.yum_staging_server, yum_path, nonfinal)
    create_rolling_repo_link(Pkg::Platforms.generic_platform_tag('osx'), Pkg::Config.dmg_staging_server, dmg_path, nonfinal)
    create_rolling_repo_link(Pkg::Platforms.generic_platform_tag('eos'), Pkg::Config.swix_staging_server, swix_path, nonfinal)
    create_rolling_repo_link(Pkg::Platforms.generic_platform_tag('windows'), Pkg::Config.msi_staging_server, msi_path, nonfinal)

    # We need to iterate through all the supported platforms here because of
    # how deb repos are set up. Each codename will have its own link from the
    # current versioned repo (e.g. puppet5) to the rolling repo. The one thing
    # we don't care about is architecture, so we just grab the first supported
    # architecture for the code name we're working with at the moment. [written
    # by Melissa, copied by Molly]

    apt_path = Pkg::Config.apt_repo_staging_path
    if nonfinal
      apt_path = Pkg::Config.nonfinal_apt_repo_staging_path
    end
    Pkg::Platforms.codenames.each do |codename|
      create_rolling_repo_link(Pkg::Platforms.codename_to_tags(codename)[0], Pkg::Config.apt_signing_server, apt_path, nonfinal)
    end
  end

  def update_release_package_symlinks(local_staging_directory, nonfinal = false)
    local_packages = collect_packages(["#{local_staging_directory}/**/*.rpm", "#{local_staging_directory}/**/*.deb"])
    local_packages.each do |package|
      platform_tag = Pkg::Paths.tag_from_artifact_path(package)
      package_format = Pkg::Platforms.package_format_for_tag(platform_tag)
      case package_format
      when 'rpm'
        remote_base = Pkg::Paths.artifacts_path(platform_tag, Pkg::Paths.remote_repo_base(platform_tag, nonfinal: nonfinal), nonfinal)
      when 'deb'
        remote_base = Pkg::Paths.apt_package_base_path(platform_tag, Pkg::Paths.repo_name(nonfinal), Pkg::Config.project, nonfinal)
      else
        fail "Unexpected package format #{package_format}, cannot create symlinks."
      end
      remote_path = File.join(remote_base, File.basename(package))
      link_path = Pkg::Paths.release_package_link_path(platform_tag, nonfinal)
      link_command = <<-CMD
        if [ ! -e #{remote_path} ]; then
          echo "Uh oh! #{remote_path} doesn't exist! Can't create symlink."
          exit 1
        fi
        if [ -e #{link_path} ] && [ ! -L #{link_path} ]; then
          echo "Uh oh! #{link_path} exists but isn't a link, I don't know what to do with this."
          exit 1
        fi
        if [ -L #{link_path} ] && [ ! #{remote_path} -ef #{link_path} ]; then
          echo "Removing old link from $(readlink #{link_path}) to #{link_path} . . ."
          rm #{link_path}
        fi
        ln -sf #{remote_path} #{link_path}
      CMD
      Pkg::Util::Net.remote_execute(Pkg::Config.staging_server, link_command)
    end
  end

  def test_ship(vm, ship_task)
    command = 'getent group release || groupadd release'
    Pkg::Util::Net.remote_execute(vm, command)
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
