# Module for shipping all packages to places

require 'English'
require 'tmpdir'

module Pkg::Util::Ship
  module_function

  def collect_packages(pkg_exts, excludes = [])
    pkgs = pkg_exts.map { |ext| Dir.glob(ext) }.flatten
    return [] if pkgs.empty?

    if excludes
      excludes.each do |exclude|
        pkgs.delete_if { |p| p.match(exclude) }
      end
    end
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
  def ship_pkgs(pkg_exts, staging_server, remote_path, opts = {})
    options = {
      excludes: [],
      chattr: true,
      platform_independent: false,
      nonfinal: false
    }.merge(opts)

    # First find the packages to be shipped. We must find them before moving
    # to our temporary staging directory
    local_packages = collect_packages(pkg_exts, options[:excludes])
    return false if local_packages.empty?

    tmpdir = Dir.mktmpdir
    staged_pkgs = reorganize_packages(
      local_packages, tmpdir, options[:platform_independent], options[:nonfinal]
    )

    puts staged_pkgs.sort
    puts "Do you want to ship the above files to (#{staging_server})?"
    return false unless Pkg::Util.ask_yes_or_no

    extra_flags = %w[--ignore-existing --delay-updates]
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

        Pkg::Util::Net.remote_set_ownership(
          staging_server, 'root', 'release', [remote_basepath, remote_pkg]
        )
        Pkg::Util::Net.remote_set_permissions(staging_server, '775', [remote_basepath])
        Pkg::Util::Net.remote_set_permissions(staging_server, '0664', [remote_pkg])
        Pkg::Util::Net.remote_set_immutable(staging_server, [remote_pkg]) if options[:chattr]
      end
    end
    return true
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
    packages_have_shipped = ship_pkgs(
      ["#{local_staging_directory}/**/*.dmg"],
      Pkg::Config.dmg_staging_server, remote_path, opts
    )

    return unless packages_have_shipped

    Pkg::Platforms.platform_tags_for_package_format('dmg').each do |platform_tag|
      # Create the latest symlink for the current supported repo
      Pkg::Util::Net.remote_create_latest_symlink(
        Pkg::Config.project,
        Pkg::Paths.artifacts_path(platform_tag, remote_path, opts[:nonfinal]),
        'dmg'
      )
    end
  end

  def ship_swix(local_staging_directory, remote_path, opts = {})
    ship_pkgs(
      ["#{local_staging_directory}/**/*.swix"],
      Pkg::Config.swix_staging_server,
      remote_path,
      opts
    )
  end

  def ship_msi(local_staging_directory, remote_path, opts = {})
    packages_have_shipped = ship_pkgs(
      ["#{local_staging_directory}/**/*.msi"],
      Pkg::Config.msi_staging_server,
      remote_path,
      opts
    )
    return unless packages_have_shipped

    # Create the symlinks for the latest supported repo
    Pkg::Util::Net.remote_create_latest_symlink(
      Pkg::Config.project,
      Pkg::Paths.artifacts_path(
        Pkg::Platforms.generic_platform_tag('windows'),
        remote_path,
        opts[:nonfinal]
      ),
      'msi',
      arch: 'x64'
    )

    Pkg::Util::Net.remote_create_latest_symlink(
      Pkg::Config.project,
      Pkg::Paths.artifacts_path(
        Pkg::Platforms.generic_platform_tag('windows'),
        remote_path,
        opts[:nonfinal]
      ),
      'msi',
      arch: 'x86'
    )
  end

  def ship_gem(local_staging_directory, remote_path, opts = {})
    ship_pkgs(["#{local_staging_directory}/*.gem*"], Pkg::Config.gem_host, remote_path, opts)
  end

  def ship_tar(local_staging_directory, remote_path, opts = {})
    ship_pkgs(
      ["#{local_staging_directory}/*.tar.gz*"],
      Pkg::Config.tar_staging_server,
      remote_path,
      opts
    )
  end

  def rolling_repo_link_command(platform_tag, repo_path, nonfinal = false)
    base_path, link_path = Pkg::Paths.artifacts_base_path_and_link_path(
      platform_tag,
      repo_path,
      nonfinal
    )

    if link_path.nil?
      puts "No link target set, not creating rolling repo link for #{base_path}"
      return nil
    end
  end

  def create_rolling_repo_link(platform_tag, staging_server, repo_path, nonfinal = false)
    command = rolling_repo_link_command(platform_tag, repo_path, nonfinal)

    Pkg::Util::Net.remote_execute(staging_server, command) unless command.nil?
  rescue StandardError => e
    fail "Failed to create rolling repo link for '#{platform_tag}'.\n#{e}\n#{e.backtrace}"
  end

  # create all of the rolling repo links in one step
  def create_rolling_repo_links(nonfinal = false)
    yum_path = Pkg::Paths.remote_repo_base(nonfinal: nonfinal, package_format: 'rpm')
    dmg_path = Pkg::Paths.remote_repo_base(nonfinal: nonfinal, package_format: 'dmg')
    swix_path = Pkg::Paths.remote_repo_base(nonfinal: nonfinal, package_format: 'swix')
    msi_path = Pkg::Paths.remote_repo_base(nonfinal: nonfinal, package_format: 'msi')

    create_rolling_repo_link(
      Pkg::Platforms.generic_platform_tag('el'),
      Pkg::Config.yum_staging_server,
      yum_path,
      nonfinal
    )

    create_rolling_repo_link(
      Pkg::Platforms.generic_platform_tag('osx'),
      Pkg::Config.dmg_staging_server,
      dmg_path,
      nonfinal
    )

    create_rolling_repo_link(
      Pkg::Platforms.generic_platform_tag('eos'),
      Pkg::Config.swix_staging_server,
      swix_path,
      nonfinal
    )

    create_rolling_repo_link(
      Pkg::Platforms.generic_platform_tag('windows'),
      Pkg::Config.msi_staging_server,
      msi_path,
      nonfinal
    )

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
      create_rolling_repo_link(
        Pkg::Platforms.codename_to_tags(codename)[0],
        Pkg::Config.apt_signing_server,
        apt_path,
        nonfinal
      )
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
    hosts_to_override = %w[
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
    ]
    hosts_to_override.each do |host|
      ENV[host] = vm
    end
    Rake::Task[ship_task].invoke
  end

  # Ship pkg directory contents to distribution server
  def ship(target = 'artifacts', local_directory = 'pkg')
    Pkg::Util::File.fetch

    unless Pkg::Config.project
      fail "You must set the 'project' in build_defaults.yaml or with the 'PROJECT_OVERRIDE' environment variable."
    end

    project_basedir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}"
    artifact_directory = "#{project_basedir}/#{target}"

    # For EZBake builds, we also want to include the ezbake.manifest file to
    # get a snapshot of this build and all dependencies. We eventually will
    # create a yaml version of this file, but until that point we want to
    # make the original ezbake.manifest available
    #
    ezbake_manifest = File.join('ext', 'ezbake.manifest')
    if File.exist?(ezbake_manifest)
      FileUtils.cp(ezbake_manifest, File.join(local_directory, "#{Pkg::Config.ref}.ezbake.manifest"))
    end
    ezbake_yaml = File.join("ext", "ezbake.manifest.yaml")
    if File.exists?(ezbake_yaml)
      FileUtils.cp(ezbake_yaml, File.join(local_directory, "#{Pkg::Config.ref}.ezbake.manifest.yaml"))
    end

    # Inside build_metadata*.json files there is additional metadata containing
    # information such as git ref and dependencies that are needed at build
    # time. If these files exist, copy them downstream.
    # Typically these files are named 'ext/build_metadata.<project>.<platform>.json'
    build_metadata_json_files = Dir.glob('ext/build_metadata*.json')
    build_metadata_json_files.each do |source_file|
      target_file = File.join(local_directory, "#{Pkg::Config.ref}.#{File.basename(source_file)}")
      FileUtils.cp(source_file, target_file)
    end

    # Sadly, the packaging repo cannot yet act on its own, without living
    # inside of a packaging-repo compatible project. This means in order to
    # use the packaging repo for shipping and signing (things that really
    # don't require build automation, specifically) we still need the project
    # clone itself.
    Pkg::Util::Git.bundle('HEAD', 'signing_bundle', local_directory)

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
      packaging_bundle = ''
      Dir.chdir(PACKAGING_ROOT) do
        packaging_bundle = Pkg::Util::Git.bundle('HEAD', 'packaging-bundle')
      end
      FileUtils.mv(packaging_bundle, local_directory)
    end

    # This is functionality to add the project-arch.msi links that have no
    # version. The code itself looks for the link (if it's there already)
    # and if the source package exists before linking. Searching for the
    # packages has been restricted specifically to just the pkg/windows dir
    # on purpose, as this is where we currently have all windows packages
    # building to. Once we move the Metadata about the output location in
    # to one source of truth we can refactor this to use that to search
    #                                           -Sean P. M. 08/12/16

    {
      'windows' => ['x86', 'x64'],
      'windowsfips' => ['x64']
    }.each_pair do |platform, archs|
      packages = Dir["#{local_directory}/#{platform}/*"]

      archs.each do |arch|
        package_version = Pkg::Util::Git.describe.tr('-', '.')
        package_filename = File.join(local_directory, platform, "#{Pkg::Config.project}-#{package_version}-#{arch}.msi")
        link_filename = File.join(local_directory, platform, "#{Pkg::Config.project}-#{arch}.msi")

        next unless !packages.include?(link_filename) && packages.include?(package_filename)
        # Dear future code spelunkers:
        # Using symlinks instead of hard links causes failures when we try
        # to set these files to be immutable. Also be wary of whether the
        # linking utility you're using expects the source path to be relative
        # to the link target or pwd.
        #
        FileUtils.ln(package_filename, link_filename)
      end
    end

    Pkg::Util::Execution.retry_on_fail(times: 3) do
      Pkg::Util::Net.remote_execute(Pkg::Config.distribution_server, "mkdir --mode=775 -p #{project_basedir}")
      Pkg::Util::Net.remote_execute(Pkg::Config.distribution_server, "mkdir -p #{artifact_directory}")
      Pkg::Util::Net.rsync_to("#{local_directory}/", Pkg::Config.distribution_server, "#{artifact_directory}/", extra_flags: ['--ignore-existing', '--exclude repo_configs'])
    end

    # In order to get a snapshot of what this build looked like at the time
    # of shipping, we also generate and ship the params file
    #
    Pkg::Config.config_to_yaml(local_directory)
    Pkg::Util::Execution.retry_on_fail(:times => 3) do
      Pkg::Util::Net.rsync_to("#{local_directory}/#{Pkg::Config.ref}.yaml", Pkg::Config.distribution_server, "#{artifact_directory}/", extra_flags: ["--exclude repo_configs"])
    end

    # If we just shipped a tagged version, we want to make it immutable
    files = Dir.glob("#{local_directory}/**/*").select { |f| File.file?(f) and !f.include? "#{Pkg::Config.ref}.yaml" }.map do |file|
      "#{artifact_directory}/#{file.sub(/^#{local_directory}\//, '')}"
    end

    Pkg::Util::Net.remote_set_ownership(Pkg::Config.distribution_server, 'root', 'release', files)
    Pkg::Util::Net.remote_set_permissions(Pkg::Config.distribution_server, '0664', files)
    Pkg::Util::Net.remote_set_immutable(Pkg::Config.distribution_server, files)
  end

  def ship_to_artifactory(local_directory = 'pkg')
    Pkg::Util::File.fetch
    unless Pkg::Config.project
      fail "You must set the 'project' in build_defaults.yaml or with the 'PROJECT_OVERRIDE' environment variable."
    end
    artifactory = Pkg::ManageArtifactory.new(Pkg::Config.project, Pkg::Config.ref)

    artifacts = Dir.glob("#{local_directory}/**/*").reject { |e| File.directory? e }
    artifacts.sort! do |a, b|
      if File.extname(a) =~ /(md5|sha\d+)/ && File.extname(b) !~ /(md5|sha\d+)/
        1
      elsif File.extname(b) =~ /(md5|sha\d+)/ && File.extname(a) !~ /(md5|sha\d+)/
        -1
      else
        a <=> b
      end
    end
    artifacts.each do |artifact|
      if File.extname(artifact) == ".yaml" || File.extname(artifact) == ".json"
        artifactory.deploy_package(artifact)
      elsif artifactory.package_exists_on_artifactory?(artifact)
        warn "Attempt to upload '#{artifact}' failed. Package already exists!"
      else
        artifactory.deploy_package(artifact)
      end
    end
  end
end
