if @build_pe
  namespace :pe do
    desc "ship PE rpms to #{@yum_host}"
    task :ship_rpms do
      check_var('PE_VER', ENV['PE_VER'])
      rsync_to('pkg/pe/', @yum_host, "#{@yum_repo_path}/#{ENV['PE_VER']}/repos/")
    end

    desc "Update remote rpm repodata for PE on #{@yum_host}"
    task :remote_update_yum_repo do
      check_var('PE_VER', ENV['PE_VER'])
      remote_ssh_cmd(@yum_host, "for dir in  $(find /opt/enterprise/#{ENV['PE_VER']}/repos/el* -type d | grep -v repodata | grep -v cache | xargs)  ; do   pushd $dir; sudo rm -rf repodata; createrepo -q -d .; popd &> /dev/null ; done; sync")
    end

    desc "Ship PE debs to #{@apt_host}"
    task :ship_debs do
      check_var('PE_VER', ENV['PE_VER'])
      rsync_to('pkg/pe/deb/', @apt_host, "#{@apt_repo_path}/#{ENV['PE_VER']}/repos/incoming/disparate/")
    end

    desc "remote freight PE packages to #{@apt_host}"
    task :remote_freight do
      check_var('PE_VER', ENV['PE_VER'])
      remote_ssh_cmd(@apt_host, "sudo deb-the-the-things #{ENV['PE_VER']}")
    end
  end
end
