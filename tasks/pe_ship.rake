if @build.build_pe
  namespace :pe do
    desc "ship PE rpms to #{@build.yum_host}"
    task :ship_rpms => "pl:fetch" do
      empty_dir?("pkg/pe/rpm") and fail "The 'pkg/pe/rpm' directory has no packages. Did you run rake pe:deb?"
      target_path = ENV['YUM_REPO'] ? ENV['YUM_REPO'] : "#{@build.yum_repo_path}/#{@build.pe_version}/repos/"
      retry_on_fail(:times => 3) do
        rsync_to('pkg/pe/rpm/', @build.yum_host, target_path)
      end
      if @build.team == 'release'
        Rake::Task["pe:remote:update_yum_repo"].invoke
      end
    end

    desc "Ship PE debs to #{@build.apt_host}"
    task :ship_debs => "pl:fetch" do
      empty_dir?("pkg/pe/deb") and fail "The 'pkg/pe/deb' directory has no packages!"
      target_path = ENV['APT_REPO'] ? ENV['APT_REPO'] : "#{@build.apt_repo_path}/#{@build.pe_version}/repos/incoming/disparate/"
      retry_on_fail(:times => 3) do
        rsync_to("pkg/pe/deb/", @build.apt_host, target_path)
      end
      if @build.team == 'release'
        Rake::Task["pe:remote:freight"].invoke
      end
    end

    namespace :remote do
      desc "Update remote rpm repodata for PE on #{@build.yum_host}"
      task :update_yum_repo => "pl:fetch" do
        remote_ssh_cmd(@build.yum_host, "for dir in  $(find #{@build.apt_repo_path}/#{@build.pe_version}/repos/el* -type d | grep -v repodata | grep -v cache | xargs)  ; do   pushd $dir; sudo rm -rf repodata; createrepo -q -d .; popd &> /dev/null ; done; sync")
      end

      # This is hacky. The freight.rb script resides on the @build.apt_host and takes packages placed
      # in the directory/structure shown in the rsync target of pe:ship_debs and adds them to the remote PE
      # freight repository and updates the apt repo metadata
      desc "remote freight PE packages to #{@build.apt_host}"
      task :freight => "pl:fetch" do
        remote_ssh_cmd(@build.apt_host, "ruby /opt/enterprise/bin/freight.rb --version #{@build.pe_version} --basedir #{@build.apt_repo_path} --config /etc/freight.conf.d/#{@build.freight_conf}")
      end
    end
  end
end
