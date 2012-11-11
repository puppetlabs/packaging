namespace :pl do
  desc "Ship mocked rpms to #{@yum_host}"
  task :ship_rpms do
    rsync_to('pkg/el', @yum_host, @yum_repo_path)
    rsync_to('pkg/fedora', @yum_host, @yum_repo_path)
  end

  desc "Update remote rpm repodata on #{@yum_host}"
  task :remote_update_yum_repo do
    STDOUT.puts "Really run remote repo update on #{@yum_host}? [y,n]"
    if ask_yes_or_no
      remote_ssh_cmd(@yum_host, '/var/lib/gems/1.8/gems/rake-0.9.2.2/bin/rake -f /opt/repository/Rakefile mk_repo')
    end
  end

  desc "Ship cow-built debs to #{@apt_host}"
  task :ship_debs do
    rsync_to('pkg/deb/', @apt_host, @apt_repo_path)
  end

  desc "freight RCs to devel repos on #{@apt_host}"
  task :remote_freight_devel do
    STDOUT.puts "Really run remote freight RC command on #{@apt_host}? [y,n]"
    if ask_yes_or_no
      override = "OVERRIDE=1" if ENV['OVERRIDE']
      # assume we're building in cows when we ship, since that's what the repo supports
      # allow OVERRIDE as well for cases where we intend to ship final-style versions to devel repos and vice versa
      remote_ssh_cmd(@apt_host, "/var/lib/gems/1.8/gems/rake-0.9.2.2/bin/rake -f /opt/repository/Rakefile devel COW=1 #{override}")
    end
  end

  desc "remote freight final packages to PRODUCTION repos on #{@apt_host}"
  task :remote_freight_final do
    STDOUT.puts "Really run remote freight final command on #{@apt_host}? [y,n]"
    if ask_yes_or_no
      override = "OVERRIDE=1" if ENV['OVERRIDE']
      remote_ssh_cmd(@apt_host, "/var/lib/gems/1.8/gems/rake-0.9.2.2/bin/rake -f /opt/repository/Rakefile community COW=1 #{override}")
    end
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
    end
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

