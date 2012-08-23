namespace :pl do
  desc "Ship mocked rpms to #{@yum_host}"
  task :ship_rpms do
    rsync_to('pkg/el', @yum_host, @yum_repo_path)
    rsync_to('pkg/fedora', @yum_host, @yum_repo_path)
  end

  desc "Update remote rpm repodata on #{@yum_host}"
  task :update_yum_repo do
    remote_ssh_cmd(@yum_host, '/var/lib/gems/1.8/gems/rake-0.9.2.2/bin/rake -I /opt/repository/ mk_repo')
  end

  desc "Ship cow-built debs to #{@apt_host}"
  task :ship_debs do
    rsync_to('pkg/deb/', @apt_host, @apt_repo_path)
  end

  desc "Ship built gem to rubygems"
  task :ship_gem do
    ship_gem("pkg/#{@name}-#{@version}.gem")
  end

end


