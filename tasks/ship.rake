namespace :pl do
  desc "Ship mocked rpms to #{@yum_host}"
  task :ship_rpms do
    rsync_to('pkg/el', @yum_host, @yum_repo_path)
    rsync_to('pkg/fedora', @yum_host, @yum_repo_path)
  end

  namespace :remote do
    # These hacky bits execute a pre-existing rake task on the @apt_host
    # The rake task takes packages in a specific directory and freights them
    # to various target yum and apt repositories based on their specific type
    # e.g., final vs devel vs PE vs FOSS packages

    desc "Update remote rpm repodata on #{@yum_host}"
    task :update_yum_repo do
      STDOUT.puts "Really run remote repo update on #{@yum_host}? [y,n]"
      if ask_yes_or_no
        remote_ssh_cmd(@yum_host, '/var/lib/gems/1.8/gems/rake-0.9.2.2/bin/rake -f /opt/repository/Rakefile mk_repo')
      end
    end

    desc "remote freight packages to repos on #{@apt_host}"
    task :freight do
      STDOUT.puts "Really run remote freight command on #{@apt_host}? [y,n]"
      if ask_yes_or_no
        override = "OVERRIDE=1" if ENV['OVERRIDE']
        remote_ssh_cmd(@apt_host, "/var/lib/gems/1.8/gems/rake-0.9.2.2/bin/rake -f /opt/repository/Rakefile freight #{override}")
      end
    end
  end

  desc "Ship cow-built debs to #{@apt_host}"
  task :ship_debs do
    rsync_to('pkg/deb/', @apt_host, @apt_repo_path)
  end

  namespace :remote do
  end

  desc "Update remote ips repository on #{@ips_host}"
  task :update_ips_repo do
    rsync_to('pkg/ips/pkgs/', @ips_host, @ips_store)
    remote_ssh_cmd(@ips_host, "pkgrecv -s #{@ips_store}/pkgs/#{@name}@#{@ipsversion}.p5p -d #{@ips_repo} \\*")
    remote_ssh_cmd(@ips_host, "pkgrepo refresh -s #{@ips_repo}")
    remote_ssh_cmd(@ips_host, "/usr/sbin/svcadm restart svc:/application/pkg/server")
  end if @build_ips

  if File.exist?("#{ENV['HOME']}/.packaging/#{@builder_data_file}")
    desc "Upload ips p5p packages to downloads"
    task :ship_ips => [ 'pl:fetch', 'pl:load_extras' ] do
      if Dir['pkg/ips/pkgs/**/*'].empty?
        STDOUT.puts "There aren't any p5p packages in pkg/ips/pkgs. Maybe something went wrong?"
      else
        rsync_to('pkg/ips/pkgs/', @ips_package_host, @ips_path)
      end
    end if @build_ips
  end

  desc "Ship built gem to rubygems"
  task :ship_gem do
    ship_gem("pkg/#{@name}-#{@gemversion}.gem")
  end if @build_gem

  if File.exist?("#{ENV['HOME']}/.packaging/#{@builder_data_file}")
    desc "ship apple dmg to #{@yum_host}"
    task :ship_dmg => ['pl:fetch', 'pl:load_extras'] do
      rsync_to('pkg/apple/*.dmg', @yum_host, @dmg_path)
    end if @build_dmg

    desc "ship tarball and signature to #{@yum_host}"
    task :ship_tar => ['pl:fetch', 'pl:load_extras'] do
      rsync_to("pkg/#{@name}-#{@version}.tar.gz*", @yum_host, @tarball_path)
    end

    desc "UBER ship: ship all the things in pkg"
    task :uber_ship => ['pl:fetch', 'pl:load_extras'] do
      if confirm_ship(FileList["pkg/**/*"])
        ENV['ANSWER_OVERRIDE'] = 'yes'
        Rake::Task["pl:ship_gem"].invoke if @build_gem
        Rake::Task["pl:ship_rpms"].invoke
        Rake::Task["pl:ship_debs"].invoke
        Rake::Task["pl:ship_dmg"].execute if @build_dmg
        Rake::Task["pl:ship_tar"].execute
      end
    end
  end
end

