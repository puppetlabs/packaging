namespace :pl do
  desc "Ship mocked rpms to #{@yum_host}"
  task :ship_rpms do
    rsync_to('pkg/el', @yum_host, @yum_repo_path)
    rsync_to('pkg/fedora', @yum_host, @yum_repo_path)
  end

  desc "Update remote rpm repodata on #{@yum_host}"
  task :update_yum_repo do
    remote_ssh_cmd(@yum_host, '/var/lib/gems/1.8/gems/rake-0.9.2.2/bin/rake -f /opt/repository/Rakefile mk_repo')
  end

  desc "Ship cow-built debs to #{@apt_host}"
  task :ship_debs do
    rsync_to('pkg/deb/', @apt_host, @apt_repo_path)
  end

  desc "Update remote ips repository on #{@ips_host}"
  task :update_ips_repo do
    rsync_to('pkg/ips/pkgs', @ips_host, @ips_store)
    remote_ssh_cmd(@ips_host, "pkgrecv -s #{@ips_store}/pkgs/#{@name}@#{@ipsversion}.p5p -d #{@ips_repo} \\*")
    remote_ssh_cmd(@ips_host, "pkgrepo refresh -s #{@ips_repo}")
    remote_ssh_cmd(@ips_host, "/usr/sbin/svcadm restart svc:/application/pkg/server")
  end

  if @build_gem == TRUE or @build_gem == 'true' or @build_gem == 'TRUE'
    desc "Ship built gem to rubygems"
    task :ship_gem do
      ship_gem("pkg/#{@name}-#{@gemversion}.gem")
    end
  end
end


