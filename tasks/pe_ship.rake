if @build_pe
  namespace :pe do
    desc "ship PE rpms to #{@yum_host}"
    task :ship_rpms => ["pl:load_extras"] do
      if empty_dir?("pkg/pe/rpm")
        STDERR.puts "The 'pkg/pe/rpm' directory has no packages. Did you run rake pe:deb?"
      else
        rsync_to('pkg/pe/rpm/', @yum_host, "#{@yum_repo_path}/#{@pe_version}/repos/")
        Rake::Task["pe:remote_update_yum_repo"].invoke
      end
    end

    desc "Update remote rpm repodata for PE on #{@yum_host}"
    task :remote_update_yum_repo => "pl:load_extras" do
      remote_ssh_cmd(@yum_host, "for dir in  $(find #{@apt_repo_path}/#{@pe_version}/repos/el* -type d | grep -v repodata | grep -v cache | xargs)  ; do   pushd $dir; sudo rm -rf repodata; createrepo -q -d .; popd &> /dev/null ; done; sync")
    end

    desc "Ship PE debs to #{@apt_host}"
    task :ship_debs => "pl:load_extras" do
      dist = @default_cow.split('-')[1]
      if empty_dir?("pkg/pe/deb/#{dist}")
        STDERR.puts "The 'pkg/pe/deb/#{dist}' directory has no packages. Did you run rake pe:deb?"
      else
        rsync_to("pkg/pe/deb/#{dist}/", @apt_host, "#{@apt_repo_path}/#{@pe_version}/repos/incoming/unified/")
        Rake::Task["pe:remote_freight"].invoke
      end
    end

    desc "remote freight PE packages to #{@apt_host}"
    task :remote_freight => "pl:load_extras" do
      remote_ssh_cmd(@apt_host, "sudo pe-the-things #{@pe_version} #{@apt_repo_path} #{@freight_conf}")
    end
  end
end
