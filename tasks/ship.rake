namespace :pl do
  desc "Ship mocked rpms to #{Pkg::Config.yum_host}"
  task :ship_rpms do
    ["el", "fedora"].each do |dist|
      retry_on_fail(:times => 3) do
        pkgs = Dir["pkg/#{dist}/**/*.rpm"].map { |f| "'#{f.gsub("pkg/#{dist}/", "#{Pkg::Config.yum_repo_path}/#{dist}/")}'" }
        unless pkgs.empty?
          Pkg::Util::Net.rsync_to("pkg/#{dist}", Pkg::Config.yum_host, Pkg::Config.yum_repo_path)
          remote_set_immutable(Pkg::Config.yum_host, pkgs)
        end
      end if File.directory?("pkg/#{dist}")
    end
  end

  namespace :remote do
    # These hacky bits execute a pre-existing rake task on the Pkg::Config.apt_host
    # The rake task takes packages in a specific directory and freights them
    # to various target yum and apt repositories based on their specific type
    # e.g., final vs devel vs PE vs FOSS packages

    desc "Update remote rpm repodata on #{Pkg::Config.yum_host}"
    task :update_yum_repo do
      STDOUT.puts "Really run remote repo update on #{Pkg::Config.yum_host}? [y,n]"
      if ask_yes_or_no
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.yum_host, 'rake -f /opt/repository/Rakefile mk_repo')
      end
    end

    desc "remote freight packages to repos on #{Pkg::Config.apt_host}"
    task :freight do
      STDOUT.puts "Really run remote freight command on #{Pkg::Config.apt_host}? [y,n]"
      if ask_yes_or_no
        override = "OVERRIDE=1" if ENV['OVERRIDE']
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.apt_host, "rake -f /opt/repository/Rakefile freight #{override}")
      end
    end
  end

  desc "Ship cow-built debs to #{Pkg::Config.apt_host}"
  task :ship_debs do
    retry_on_fail(:times => 3) do
      if File.directory?("pkg/deb")
        Pkg::Util::Net.rsync_to('pkg/deb/', Pkg::Config.apt_host, Pkg::Config.apt_repo_path)
      end
    end
  end

  namespace :remote do
  end

  desc "Update remote ips repository on #{Pkg::Config.ips_host}"
  task :update_ips_repo do
    Pkg::Util::Net.rsync_to('pkg/ips/pkgs/', Pkg::Config.ips_host, Pkg::Config.ips_store)
    Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.ips_host, "pkgrecv -s #{Pkg::Config.ips_store}/pkgs/#{Pkg::Config.project}Pkg::Config.#{Pkg::Config.ipsversion}.p5p -d #{Pkg::Config.ips_repo} \\*")
    Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.ips_host, "pkgrepo refresh -s #{Pkg::Config.ips_repo}")
    Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.ips_host, "/usr/sbin/svcadm restart svc:/application/pkg/server")
  end if Pkg::Config.build_ips

  desc "Upload ips p5p packages to downloads"
  task :ship_ips => 'pl:fetch' do
    if Dir['pkg/ips/pkgs/**/*'].empty?
      STDOUT.puts "There aren't any p5p packages in pkg/ips/pkgs. Maybe something went wrong?"
    else
      Pkg::Util::Net.rsync_to('pkg/ips/pkgs/', Pkg::Config.ips_package_host, Pkg::Config.ips_path)
    end
  end if Pkg::Config.build_ips

  # We want to ship a gem only for projects that build gems
  if Pkg::Config.build_gem
    desc "Ship built gem to rubygems"
    task :ship_gem do
      # Even if a project builds a gem, if it uses the odd_even or zero-based
      # strategies, we only want to ship final gems because otherwise a
      # development gem would be preferred over the last final gem
      if Pkg::Config.version_strategy !~ /odd_even|zero_based/ || Pkg::Util::Version.is_final?
        FileList["pkg/#{Pkg::Config.gem_name}-#{Pkg::Config.gemversion}*.gem"].each do |f|
          puts "Shipping gem #{f} to rubygems"
          ship_gem(f)
        end
      else
        STDERR.puts "Not shipping development gem using odd_even strategy for the sake of your users."
      end
    end
  end

  desc "ship apple dmg to #{Pkg::Config.yum_host}"
  task :ship_dmg => 'pl:fetch' do
    retry_on_fail(:times => 3) do
      Pkg::Util::Net.rsync_to('pkg/apple/*.dmg', Pkg::Config.yum_host, Pkg::Config.dmg_path)
    end
  end if Pkg::Config.build_dmg

  desc "ship tarball and signature to #{Pkg::Config.tar_host}"
  task :ship_tar => 'pl:fetch' do
    retry_on_fail(:times => 3) do
      Pkg::Util::Net.rsync_to("pkg/#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz*", Pkg::Config.tar_host, Pkg::Config.tarball_path)
    end
  end

  desc "UBER ship: ship all the things in pkg"
  task :uber_ship => 'pl:fetch' do
    if confirm_ship(FileList["pkg/**/*"])
      ENV['ANSWER_OVERRIDE'] = 'yes'
      Rake::Task["pl:ship_gem"].invoke if Pkg::Config.build_gem
      Rake::Task["pl:ship_rpms"].invoke
      Rake::Task["pl:ship_debs"].invoke
      Rake::Task["pl:ship_dmg"].execute if Pkg::Config.build_dmg
      Rake::Task["pl:ship_tar"].execute
      Rake::Task["pl:jenkins:ship"].invoke("shipped")
      add_shipped_metrics(:pe_version => ENV['PE_VER'], :is_rc => (!Pkg::Util::Version.is_final?)) if Pkg::Config.benchmark
      post_shipped_metrics if Pkg::Config.benchmark
    else
      puts "Ship canceled"
      exit
    end
  end

  # It is odd to namespace this ship task under :jenkins, but this task is
  # intended to be a component of the jenkins-based build workflow even if it
  # doesn't interact with jenkins directly. The :target argument is so that we
  # can invoke this task with a subdirectory of the standard distribution
  # server path. That way we can separate out built artifacts from
  # signed/actually shipped artifacts e.g. $path/shipped/ or $path/artifacts.
  namespace :jenkins do
    desc "Ship pkg directory contents to distribution server"
    task :ship, :target do |t, args|
      invoke_task("pl:fetch")
      target = args.target || "artifacts"
      artifact_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/#{target}"

      # In order to get a snapshot of what this build looked like at the time
      # of shipping, we also generate and ship the params file
      #
      Pkg::Config.config_to_yaml('pkg')


      # Sadly, the packaging repo cannot yet act on its own, without living
      # inside of a packaging-repo compatible project. This means in order to
      # use the packaging repo for shipping and signing (things that really
      # don't require build automation, specifically) we still need the project
      # clone itself.
      Pkg::Util::Git.git_bundle('HEAD', 'signing_bundle', 'pkg')

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
          packaging_bundle = Pkg::Util::Git.git_bundle('HEAD', 'packaging-bundle')
        end
        mv(packaging_bundle, 'pkg')
      end

      retry_on_fail(:times => 3) do
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir -p #{artifact_dir}")
        Pkg::Util::Net.rsync_to("pkg/", Pkg::Config.distribution_server, "#{artifact_dir}/", ["--ignore-existing", "--exclude repo_configs"])
      end

      # If we just shipped a tagged version, we want to make it immutable
      files = Dir.glob("pkg/**/*").select { |f| File.file?(f) }.map do |file|
        "#{artifact_dir}/#{file.sub(/^pkg\//, '')}"
      end
      remote_set_immutable(Pkg::Config.distribution_server, files)
    end

    desc "Ship generated repository configs to the distribution server"
    task :ship_repo_configs do
      Pkg::Deb::Repo.ship_repo_configs
      Pkg::Rpm::Repo.ship_repo_configs
    end
  end
end

