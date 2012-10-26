if @build_pe
  namespace :pe do
    desc "ship PE rpms to #{@yum_host}"
    task :ship_rpms do
      check_var('PE_VER', ENV['PE_VER'])
      rsync_to('pkg/pe/', @yum_host, "#{@yum_repo_path}/#{ENV['PE_VER']}/repos/")
      Rake::Task["pe:remote_update_yum_repo"].invoke
    end

    desc "Update remote rpm repodata for PE on #{@yum_host}"
    task :remote_update_yum_repo do
      check_var('PE_VER', ENV['PE_VER'])
      remote_ssh_cmd(@yum_host, "for dir in  $(find #{@apt_repo_path}/#{ENV['PE_VER']}/repos/el* -type d | grep -v repodata | grep -v cache | xargs)  ; do   pushd $dir; sudo rm -rf repodata; createrepo -q -d .; popd &> /dev/null ; done; sync")
    end

    desc "Ship PE debs to #{@apt_host}"
    task :ship_debs do
      check_var('PE_VER', ENV['PE_VER'])
      dist = @default_cow.split('-')[1]
      if Dir["pkg/pe/deb/#{dist}/*"].empty?
        STDERR.puts "The pkg/pe/deb/#{dist} directory has no packages. Did you run rake pe:deb?"
      else
        rsync_to("pkg/pe/deb/#{dist}/", @apt_host, "#{@apt_repo_path}/#{ENV['PE_VER']}/repos/incoming/unified/")
        Rake::Task["pe:remote_freight"].invoke
      end
    end

    desc "remote freight PE packages to #{@apt_host}"
    task :remote_freight do
      check_var('PE_VER', ENV['PE_VER'])
      remote_ssh_cmd(@apt_host, "sudo pe-the-things #{ENV['PE_VER']} #{@apt_repo_path}")
    end
  end
end
