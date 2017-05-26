namespace :pl do
  desc "Ship mocked rpms to #{Pkg::Config.yum_staging_server}"
  task :ship_rpms => 'pl:fetch' do
    ["aix", "cisco-wrlinux", "el", "eos", "fedora", "nxos", "sles"].each do |dist|
      pkgs = Dir["pkg/#{dist}/**/*.rpm"]
      next if pkgs.empty?

      prefix = File.join(Pkg::Config.yum_repo_path, dist)
      pkgs = pkgs.map { |f| f.gsub("pkg/#{dist}", prefix) }

      extra_flags = ['--ignore-existing', '--delay-updates']
      extra_flags << '--dry-run' if ENV['DRYRUN']

      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        Pkg::Util::Net.rsync_to(
          "pkg/#{dist}",
          Pkg::Config.yum_staging_server,
          Pkg::Config.yum_repo_path,
          extra_flags: extra_flags
        )

        Pkg::Util::Net.remote_set_ownership(Pkg::Config.yum_staging_server, 'root', 'release', pkgs)
        Pkg::Util::Net.remote_set_permissions(Pkg::Config.yum_staging_server, '0664', pkgs)
        Pkg::Util::Net.remote_set_immutable(Pkg::Config.yum_staging_server, pkgs)
      end
    end
  end

  namespace :remote do
    # These hacky bits execute a pre-existing rake task on the Pkg::Config.apt_host
    # The rake task takes packages in a specific directory and freights them
    # to various target yum and apt repositories based on their specific type
    # e.g., final vs devel vs PE vs FOSS packages

    desc "Update remote yum repository on '#{Pkg::Config.yum_staging_server}'"
    task update_yum_repo: 'pl:fetch' do
      yum_whitelist = {
        __REPO_NAME__: Pkg::Config.repo_name,
        __REPO_PATH__: Pkg::Config.yum_repo_path,
        __REPO_HOST__: Pkg::Config.yum_staging_server,
        __GPG_KEY__: Pkg::Config.gpg_key
      }

      $stdout.puts "Really run remote repo update on '#{Pkg::Config.yum_staging_server}'? [y,n]"
      if Pkg::Util.ask_yes_or_no
        if Pkg::Config.yum_repo_command
          Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.yum_staging_server, Pkg::Util::Misc.search_and_replace(Pkg::Config.yum_repo_command, yum_whitelist))
        else
          Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.yum_staging_server, 'rake -f /opt/repository/Rakefile mk_repo')
        end
      end
    end

    task freight: :update_apt_repo

    desc "Update remote apt repository on '#{Pkg::Config.apt_signing_server}'"
    task update_apt_repo: 'pl:fetch' do
      apt_whitelist = {
        __REPO_NAME__: Pkg::Config.repo_name,
        __REPO_PATH__: Pkg::Config.apt_repo_path,
        __REPO_URL__: Pkg::Config.apt_repo_url,
        __REPO_HOST__: Pkg::Config.apt_host,
        __APT_PLATFORMS__: Pkg::Config.apt_releases.join(' '),
        __GPG_KEY__: Pkg::Config.gpg_key
      }

      $stdout.puts "Really run remote repo update on '#{Pkg::Config.apt_signing_server}'? [y,n]"
      if Pkg::Util.ask_yes_or_no
        if Pkg::Config.apt_repo_command
          Pkg::Util::Net.remote_ssh_cmd(
            Pkg::Config.apt_signing_server,
            Pkg::Util::Misc.search_and_replace(
              Pkg::Config.apt_repo_command,
              apt_whitelist
            )
          )
        else
          warn %(Pkg::Config#apt_repo_command returned something unexpected, so no attempt will be made to update remote repos)
        end
      end
    end
  end

  desc "Ship cow-built debs to #{Pkg::Config.apt_signing_server}"
  task :ship_debs => 'pl:fetch' do
    Pkg::Util::Execution.retry_on_fail(:times => 3) do
      if File.directory?("pkg/deb")

        pkgs = Dir["pkg/deb/**/*\.*"]
        pkgs = pkgs.map { |f| f.gsub("pkg/deb", Pkg::Config.apt_repo_staging_path) }
        puts "pkgs = #{pkgs}"

        Pkg::Util::Net.rsync_to('pkg/deb/', Pkg::Config.apt_signing_server, Pkg::Config.apt_repo_staging_path)
        Pkg::Util::Net.remote_set_ownership(Pkg::Config.apt_signing_server, 'root', 'release', pkgs)
        Pkg::Util::Net.remote_set_permissions(Pkg::Config.apt_signing_server, '0664', pkgs)
      else
        warn "No deb packages found to ship; nothing to do"
      end
    end
  end

  desc "Ship svr4 packages to #{Pkg::Config.svr4_host}"
  task :ship_svr4 do
    Pkg::Util::Execution.retry_on_fail(:times => 3) do
      if File.directory?("pkg/solaris/10")
        Pkg::Util::Net.rsync_to('pkg/solaris/10', Pkg::Config.svr4_host, Pkg::Config.svr4_path)
      end
    end
  end

  desc "Ship p5p packages to #{Pkg::Config.p5p_host}"
  task :ship_p5p do
    Pkg::Util::Execution.retry_on_fail(:times => 3) do
      if File.directory?("pkg/solaris/11")
        Pkg::Util::Net.rsync_to('pkg/solaris/11', Pkg::Config.p5p_host, Pkg::Config.p5p_path)
      end
    end
  end

  namespace :remote do
    desc "Update remote ips repository on #{Pkg::Config.ips_host}"
    task :update_ips_repo  => 'pl:fetch' do
      if Dir['pkg/ips/pkgs/**/*'].empty? && Dir['pkg/solaris/11/**/*'].empty?
        $stdout.puts "There aren't any p5p packages in pkg/ips/pkgs or pkg/solaris/11. Maybe something went wrong?"
      else

        if !Dir['pkg/ips/pkgs/**/*'].empty?
          source_dir = 'pkg/ips/pkgs/'
        else
          source_dir = 'pkg/solaris/11/'
        end

        tmpdir, _ = Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.ips_host, 'mktemp -d -p /var/tmp', true)
        tmpdir.chomp!

        Pkg::Util::Net.rsync_to(source_dir, Pkg::Config.ips_host, tmpdir)

        remote_cmd = %(for pkg in #{tmpdir}/*.p5p; do
      sudo pkgrecv -s $pkg -d #{Pkg::Config.ips_path} '*';
      done)

        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.ips_host, remote_cmd)
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.ips_host, "sudo pkgrepo refresh -s #{Pkg::Config.ips_path}")
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.ips_host, "sudo /usr/sbin/svcadm restart svc:/application/pkg/server:#{Pkg::Config.ips_repo || 'default'}")
      end
    end

    desc "Move dmg repos from #{Pkg::Config.dmg_staging_server} to #{Pkg::Config.dmg_host}"
    task deploy_dmg_repo: 'pl:fetch' do
      puts "Really run remote rsync to deploy OS X repos from #{Pkg::Config.dmg_staging_server} to #{Pkg::Config.dmg_host}? [y,n]"
      if Pkg::Util.ask_yes_or_no
        Pkg::Util::Execution.retry_on_fail(times: 3) do
          cmd = Pkg::Util::Net.rsync_cmd(Pkg::Config.dmg_path, target_host: Pkg::Config.dmg_host, extra_flags: ['--update'])
          Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.dmg_staging_server, cmd)
        end
      end
    end

    desc "Move swix repos from #{Pkg::Config.swix_staging_server} to #{Pkg::Config.swix_host}"
    task deploy_swix_repo: 'pl:fetch' do
      puts "Really run remote rsync to deploy Arista repos from #{Pkg::Config.swix_staging_server} to #{Pkg::Config.swix_host}? [y,n]"
      if Pkg::Util.ask_yes_or_no
        Pkg::Util::Execution.retry_on_fail(times: 3) do
          cmd = Pkg::Util::Net.rsync_cmd(Pkg::Config.swix_path, target_host: Pkg::Config.swix_host, extra_flags: ['--update'])
          Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.swix_staging_server, cmd)
        end
      end
    end

    desc "Move tar repos from #{Pkg::Config.tar_staging_server} to #{Pkg::Config.tar_host}"
    task deploy_tar_repo: 'pl:fetch' do
      puts "Really run remote rsync to deploy source tarballs from #{Pkg::Config.tar_staging_server} to #{Pkg::Config.tar_host}? [y,n]"
      if Pkg::Util.ask_yes_or_no
        files = Dir.glob("pkg/#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz*")
        if files.empty?
          puts 'There are no tarballs to ship'
        else
          Pkg::Util::Execution.retry_on_fail(times: 3) do
            cmd = Pkg::Util::Net.rsync_cmd(Pkg::Config.tarball_path, target_host: Pkg::Config.tar_host, extra_flags: ['--update'])
            Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.tar_staging_server, cmd)
          end
        end
      end
    end

    desc "Move MSI repos from #{Pkg::Config.msi_staging_server} to #{Pkg::Config.msi_host}"
    task deploy_msi_repo: 'pl:fetch' do
      puts "Really run remote rsync to deploy source MSIs from #{Pkg::Config.msi_staging_server} to #{Pkg::Config.msi_host}? [y,n]"
      if Pkg::Util.ask_yes_or_no
        files = Dir.glob('pkg/windows/**/*.msi')
        if files.empty?
          puts 'There are no MSIs to ship'
        else
          Pkg::Util::Execution.retry_on_fail(times: 3) do
            cmd = Pkg::Util::Net.rsync_cmd(Pkg::Config.msi_path, target_host: Pkg::Config.msi_host, extra_flags: ['--update'])
            Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.msi_staging_server, cmd)
          end
        end
      end
    end

    desc "Move signed deb repos from #{Pkg::Config.apt_signing_server} to #{Pkg::Config.apt_host}"
    task deploy_apt_repo: 'pl:fetch' do
      puts "Really run remote rsync to deploy Debian repos from #{Pkg::Config.apt_signing_server} to #{Pkg::Config.apt_host}? [y,n]"
      if Pkg::Util.ask_yes_or_no
        Pkg::Util::Execution.retry_on_fail(times: 3) do
          Pkg::Deb::Repo.deploy_repos(
            Pkg::Config.apt_repo_path,
            Pkg::Config.apt_repo_staging_path,
            Pkg::Config.apt_signing_server,
            Pkg::Config.apt_host,
            ENV['DRYRUN']
          )
        end
      end
    end

    desc "Copy rpm repos from #{Pkg::Config.yum_staging_server} to #{Pkg::Config.yum_host}"
    task deploy_yum_repo: 'pl:fetch' do
      puts "Really run remote rsync to deploy yum repos from #{Pkg::Config.yum_staging_server} to #{Pkg::Config.yum_host}? [y,n]"
      if Pkg::Util.ask_yes_or_no
        Pkg::Util::Execution.retry_on_fail(times: 3) do
          Pkg::Rpm::Repo.deploy_repos(
            Pkg::Config.yum_repo_path,
            Pkg::Config.yum_staging_server,
            Pkg::Config.yum_host,
            ENV['DRYRUN']
          )
        end
      end
    end
  end

  desc 'Ship built gem to rubygems.org, internal Gem mirror, and public file server'
  task ship_gem: 'pl:fetch' do
    # We want to ship a Gem only for projects that build gems, so
    # all of the Gem shipping tasks are wrapped in an `if`.
    if Pkg::Config.build_gem
      # Even if a project builds a gem, if it uses the odd_even or zero-based
      # strategies, we only want to ship final gems because otherwise a
      # development gem would be preferred over the last final gem
      if Pkg::Util::Version.final?
        FileList['pkg/*.gem'].each do |gem_file|
          puts 'This will ship to an internal gem mirror, a public file server, and rubygems.org'
          puts "Do you want to start shipping the rubygem '#{gem_file}'?"
          next unless Pkg::Util.ask_yes_or_no
          Rake::Task['pl:ship_gem_to_rubygems'].execute(file: gem_file)
          Rake::Task['pl:ship_gem_to_internal_mirror'].execute(file: gem_file)
          Rake::Task['pl:ship_gem_to_downloads'].execute(file: gem_file)
        end
      else
        $stderr.puts 'Not shipping development gem using odd_even strategy for the sake of your users.'
      end
    end
  end

  desc 'Ship built gem to rubygems.org'
  task :ship_gem_to_rubygems, [:file] => 'pl:fetch' do |_t, args|
    puts "Do you want to ship #{args[:file]} to rubygems.org?"
    if Pkg::Util.ask_yes_or_no
      puts "Shipping gem #{args[:file]} to rubygems.org"
      Pkg::Util::Execution.retry_on_fail(times: 3) do
        Pkg::Gem.ship_to_rubygems(args[:file])
      end
    end
  end

  desc "Ship built gems to internal Gem server (#{Pkg::Config.internal_gem_host})"
  task :ship_gem_to_internal_mirror, [:file] => 'pl:fetch' do |_t, args|
    unless Pkg::Config.internal_gem_host
      warn 'Value `Pkg::Config.internal_gem_host` not defined; skipping internal ship'
    end

    puts "Do you want to ship #{args[:file]} to the internal stickler server(#{Pkg::Config.internal_stickler_host})?"
    if Pkg::Util.ask_yes_or_no
      puts "Shipping gem #{args[:file]} to internal Gem server (#{Pkg::Config.internal_stickler_host})"
      Pkg::Util::Execution.retry_on_fail(times: 3) do
        Pkg::Gem.ship_to_stickler(args[:file])
      end
    end

    puts "Do you want to ship #{args[:file]} to the internal nexus server(#{Pkg::Config.internal_nexus_host})?"
    if Pkg::Util.ask_yes_or_no
      puts "Shipping gem #{args[:file]} to internal Gem server (#{Pkg::Config.internal_nexus_host})"
      Pkg::Util::Execution.retry_on_fail(times: 3) do
        Pkg::Gem.ship_to_nexus(args[:file])
      end
    end
  end

  desc "Ship built gems to public Downloads server (#{Pkg::Config.gem_host})"
  task :ship_gem_to_downloads, [:file] => 'pl:fetch' do |_t, args|
    unless Pkg::Config.gem_host
      warn 'Value `Pkg::Config.gem_host` not defined; skipping shipping to public Download server'
    end

    puts "Do you want to ship #{args[:file]} to public file server (#{Pkg::Config.gem_host})?"
    if Pkg::Util.ask_yes_or_no
      puts "Shipping gem #{args[:file]} to public file server (#{Pkg::Config.gem_host})"
      Pkg::Util::Execution.retry_on_fail(times: 3) do
        Pkg::Gem.rsync_to_downloads(args[:file])
      end
    end
  end

  desc "ship apple dmg to #{Pkg::Config.dmg_staging_server}"
  task :ship_dmg => 'pl:fetch' do
    if Dir['pkg/apple/**/*.dmg'].empty?
      $stdout.puts "There aren't any dmg packages in pkg/apple. Maybe something went wrong?"
    else
      puts "Do you want to ship dmg files to (#{Pkg::Config.dmg_staging_server})?"
      if Pkg::Util.ask_yes_or_no
        Pkg::Util::Execution.retry_on_fail(:times => 3) do
          Pkg::Util::Net.rsync_to('pkg/apple/', Pkg::Config.dmg_staging_server, Pkg::Config.dmg_path)
        end
      end
    end
  end

  desc "ship Arista EOS swix packages and signatures to #{Pkg::Config.swix_staging_server}"
  task :ship_swix => 'pl:fetch' do
    packages = Dir['pkg/eos/**/*.swix']
    if packages.empty?
      $stdout.puts "There aren't any swix packages in pkg/eos. Maybe something went wrong?"
    else
      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        Pkg::Util::Net.rsync_to("pkg/eos/", Pkg::Config.swix_staging_server, Pkg::Config.swix_path)
      end
    end
  end

  desc "ship tarball and signature to #{Pkg::Config.tar_staging_server}"
  task ship_tar: 'pl:fetch' do
    if Pkg::Config.build_tar
      files = Dir.glob("pkg/#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz*")
      if files.empty?
        puts "There are no tarballs to ship"
      else
        Pkg::Util::Execution.retry_on_fail(:times => 3) do
          Pkg::Util::Net.rsync_to(files.join("\s"), Pkg::Config.tar_staging_server, Pkg::Config.tarball_path)
        end
      end
    end
  end

  desc "ship Windows nuget packages to #{Pkg::Config.nuget_host}"
  task ship_nuget: 'pl:fetch' do
    packages = Dir['pkg/**/*.nupkg']
    if packages.empty?
      $stdout.puts "There aren't any nuget packages in pkg/windows. Maybe something went wrong?"
    else
      Pkg::Nuget.ship(packages)
    end
  end

  desc "Ship MSI packages to #{Pkg::Config.msi_staging_server}"
  task :ship_msi => 'pl:fetch' do
    files = Dir["pkg/windows/**/#{Pkg::Config.project}-#{Pkg::Config.version}*.msi"]
    if files.empty?
      $stdout.puts "There aren't any MSI packages in pkg/windows. Maybe something went wrong?"
    else
      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        if File.directory?("pkg/windows")
          Pkg::Util::Net.rsync_to(
            'pkg/windows/',
            Pkg::Config.msi_staging_server,
            Pkg::Config.msi_path,
            extra_flags: %W(
              --ignore-existing
              --include="*#{Pkg::Config.project}-#{Pkg::Config.version}*.msi"
              --include="*/"
              --exclude="*"
            )
          )
        end
      end
    end
  end

  desc 'UBER ship: ship all the things in pkg'
  task uber_ship: 'pl:fetch' do
    if Pkg::Util.confirm_ship(FileList['pkg/**/*'])
      Rake::Task['pl:ship_rpms'].invoke
      Rake::Task['pl:ship_debs'].invoke
      Rake::Task['pl:ship_dmg'].invoke
      Rake::Task['pl:ship_swix'].invoke
      Rake::Task['pl:ship_nuget'].invoke
      Rake::Task['pl:ship_tar'].invoke
      Rake::Task['pl:ship_svr4'].invoke
      Rake::Task['pl:ship_p5p'].invoke
      Rake::Task['pl:ship_msi'].invoke
      add_shipped_metrics(pe_version: ENV['PE_VER'], is_rc: !Pkg::Util::Version.final?) if Pkg::Config.benchmark
      post_shipped_metrics if Pkg::Config.benchmark
    else
      puts 'Ship canceled'
      exit
    end
  end

  desc 'Test out the ship requirements'
  task ship_check: 'pl:fetch' do
    errs = []
    ssh_errs = []
    gpg_errs = []

    if ENV['TEAM']
      unless ENV['TEAM'] == 'release'
        errs << "TEAM environment variable is #{ENV['TEAM']}. It should be 'release'"
      end
    else
      errs << 'TEAM environment variable is not set. This should be set to release'
    end
    # Check SSH access to the staging servers
    ssh_errs << Pkg::Util::Net.check_host_ssh(Pkg::Util.filter_configs('staging_server').values.uniq)
    # Check SSH access to the signing servers, with some windows special-ness
    ssh_errs << Pkg::Util::Net.check_host_ssh(Pkg::Util.filter_configs('signing_server').values.uniq - [Pkg::Config.msi_signing_server])
    ssh_errs << Pkg::Util::Net.check_host_ssh("Administrator@#{Pkg::Config.msi_signing_server}")
    # Check SSH access to the final shipped hosts
    ssh_errs << Pkg::Util::Net.check_host_ssh(Pkg::Util.filter_configs('^(?!.*(?=build|internal)).*_host$').values.uniq)
    ssh_errs.flatten!
    unless ssh_errs.empty?
      ssh_errs.each do |host|
        errs << "Unable to ssh to #{host}"
      end
    end

    # Check for GPG on linux-y systems
    gpg_errs << Pkg::Util::Net.check_host_gpg(Pkg::Config.apt_signing_server, Pkg::Config.gpg_key)
    gpg_errs << Pkg::Util::Net.check_host_gpg(Pkg::Config.distribution_server, Pkg::Config.gpg_key)
    gpg_errs.flatten!
    # ignore gpg errors for hosts we couldn't ssh into
    gpg_errs -= ssh_errs
    unless gpg_errs.empty?
      gpg_errs.each do |host|
        errs << "Secret key #{Pkg::Config.gpg_key} not found on #{host}"
      end
    end

    # For windows and solaris it looks like as long as you have ssh access
    # to the signers you should be able to sign. If this changes in the future
    # we should add more checks here, but for now it should be fine.
    # Check for ability to sign OSX. Should just need to be able to unlock keychain
    begin
      unless ssh_errs.include?(Pkg::Config.osx_signing_server)
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.osx_signing_server, %(/usr/bin/security -q unlock-keychain -p "#{Pkg::Config.osx_signing_keychain_pw}" "#{Pkg::Config.osx_signing_keychain}"), false, '-oBatchMode=yes')
      end
    rescue
      errs << "Unlocking the OSX keychain failed! Check the password in your .bashrc on #{Pkg::Config.osx_signing_server}"
    end

    if Pkg::Config.build_gem
      # Do we have stickler and nexus?
      if Pkg::Util::Misc.check_gem('stickler')
        `stickler list --server #{Pkg::Config.internal_stickler_host} > /dev/null 2>&1`
        unless $CHILD_STATUS.zero?
          errs << "Listing gems at the stickler server #{Pkg::Config.internal_stickler_host} failed!"
        end
      else
        errs << 'gem stickler not found'
      end

      errs << 'gem nexus not found' unless Pkg::Util::Misc.check_gem('nexus')
      `gem list --source #{Pkg::Config.internal_nexus_host} > /dev/null 2>&1`
      unless $CHILD_STATUS.zero?
        errs << "Listing gems at the nexus server #{Pkg::Config.internal_nexus_host} failed!"
      end

      # Do we have rubygems access set up
      if Pkg::Util::File.file_exists?("#{ENV['HOME']}/.gem/credentials")
        # Do we have permissions to publish this gem on rubygems
        unless Pkg::Util::Misc.check_rubygems_ownership(Pkg::Config.gem_name)
          errs << "You don't own #{Pkg::Config.gem_name} on rubygems.org"
        end
      else
        errs << "You haven't set up your .gem/credentials file for rubygems.org access"
      end
    end

    puts "\n\n"
    if errs.empty?
      puts 'Hooray! You should be good for shipping!'
    else
      puts "Found #{errs.length} issues:"
      errs.each do |err|
        puts " * #{err}"
      end
    end
  end

  # It is odd to namespace this ship task under :jenkins, but this task is
  # intended to be a component of the jenkins-based build workflow even if it
  # doesn't interact with jenkins directly. The :target argument is so that we
  # can invoke this task with a subdirectory of the standard distribution
  # server path. That way we can separate out built artifacts from
  # signed/actually shipped artifacts e.g. $path/shipped/ or $path/artifacts.
  namespace :jenkins do
    desc 'Ship pkg directory contents to distribution server'
    task :ship, :target, :local_dir do |_t, args|
      Pkg::Util::RakeUtils.invoke_task('pl:fetch')
      target = args.target || 'artifacts'
      local_dir = args.local_dir || 'pkg'
      project_basedir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}"
      artifact_dir = "#{project_basedir}/#{target}"

      # In order to get a snapshot of what this build looked like at the time
      # of shipping, we also generate and ship the params file
      #
      Pkg::Config.config_to_yaml(local_dir)

      # For EZBake builds, we also want to include the ezbake.manifest file to
      # get a snapshot of this build and all dependencies. We eventually will
      # create a yaml version of this file, but until that point we want to
      # make the original ezbake.manifest available
      #
      ezbake_manifest = File.join('ext', 'ezbake.manifest')
      if File.exist?(ezbake_manifest)
        cp(ezbake_manifest, File.join(local_dir, "#{Pkg::Config.ref}.ezbake.manifest"))
      end
      ezbake_yaml = File.join('ext', 'ezbake.manifest.yaml')
      if File.exist?(ezbake_yaml)
        cp(ezbake_yaml(File.join(local_dir, "#{Pkg::Config.ref}.ezbake.manifest.yaml")))
      end

      # Sadly, the packaging repo cannot yet act on its own, without living
      # inside of a packaging-repo compatible project. This means in order to
      # use the packaging repo for shipping and signing (things that really
      # don't require build automation, specifically) we still need the project
      # clone itself.
      Pkg::Util::Git.bundle('HEAD', 'signing_bundle', local_dir)

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
        cd PACKAGING_ROOT do
          packaging_bundle = Pkg::Util::Git.bundle('HEAD', 'packaging-bundle')
        end
        mv(packaging_bundle, local_dir)
      end

      # This is functionality to add the project-arch.msi links that have no
      # version. The code itself looks for the link (if it's there already)
      # and if the source package exists before linking. Searching for the
      # packages has been restricted specifically to just the pkg/windows dir
      # on purpose, as this is where we currently have all windows packages
      # building to. Once we move the Metadata about the output location in
      # to one source of truth we can refactor this to use that to search
      #                                           -Sean P. M. 08/12/16
      packages = Dir["#{local_dir}/windows/*"]
      ['x86', 'x64'].each do |arch|
        package_version = Pkg::Util::Git.describe.tr('-', '.')
        package_filename = File.join(local_dir, 'windows', "#{Pkg::Config.project}-#{package_version}-#{arch}.msi")
        link_filename = File.join(local_dir, 'windows', "#{Pkg::Config.project}-#{arch}.msi")

        next unless !packages.include?(link_filename) && packages.include?(package_filename)
        # Dear future code spelunkers:
        # Using symlinks instead of hard links causes failures when we try
        # to set these files to be immutable. Also be wary of whether the
        # linking utility you're using expects the source path to be relative
        # to the link target or pwd.
        #
        FileUtils.ln(package_filename, link_filename)
      end

      Pkg::Util::Execution.retry_on_fail(times: 3) do
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir --mode=775 -p #{project_basedir}")
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir -p #{artifact_dir}")
        Pkg::Util::Net.rsync_to("#{local_dir}/", Pkg::Config.distribution_server, "#{artifact_dir}/", extra_flags: ['--ignore-existing', '--exclude repo_configs'])
      end

      # If we just shipped a tagged version, we want to make it immutable
      files = Dir.glob("#{local_dir}/**/*").select { |f| File.file?(f) }.map do |file|
        "#{artifact_dir}/#{file.sub(/^#{local_dir}\//, '')}"
      end

      Pkg::Util::Net.remote_set_ownership(Pkg::Config.distribution_server, 'root', 'release', files)
      Pkg::Util::Net.remote_set_permissions(Pkg::Config.distribution_server, '0664', files)
      Pkg::Util::Net.remote_set_immutable(Pkg::Config.distribution_server, files)
    end

    desc 'Ship generated repository configs to the distribution server'
    task :ship_repo_configs do
      Pkg::Deb::Repo.ship_repo_configs
      Pkg::Rpm::Repo.ship_repo_configs
    end
  end
end
