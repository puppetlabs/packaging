if @build_pe
  namespace :pe do
    desc "ship PE rpms to #{@yum_host}"
    task :ship_rpms => ["pl:load_extras"] do
      if empty_dir?("pkg/pe/rpm")
        STDERR.puts "The 'pkg/pe/rpm' directory has no packages. Did you run rake pe:deb?"
        exit 1
      else
        target_path = ENV['YUM_REPO'] ? ENV['YUM_REPO'] : "#{@yum_repo_path}/#{@pe_version}/repos/"
        rsync_to('pkg/pe/rpm/', @yum_host, target_path)
        if @team == 'release'
          Rake::Task["pe:remote:update_yum_repo"].invoke
        end
      end
    end

    desc "Ship PE debs to #{@apt_host}"
    task :ship_debs => "pl:load_extras" do
      dist = @default_cow.split('-')[1]
      if empty_dir?("pkg/pe/deb/#{dist}")
        STDERR.puts "The 'pkg/pe/deb/#{dist}' directory has no packages. Did you run rake pe:deb?"
        exit 1
      else
        target_path = ENV['APT_REPO'] ? ENV['APT_REPO'] : "#{@apt_repo_path}/#{@pe_version}/repos/incoming/unified/"
        rsync_to("pkg/pe/deb/#{dist}/", @apt_host, target_path)
        if @team == 'release'
          Rake::Task["pe:remote:freight"].invoke
        end
      end
    end

    namespace :remote do
      desc "Update remote rpm repodata for PE on #{@yum_host}"
      task :update_yum_repo => "pl:load_extras" do
        remote_ssh_cmd(@yum_host, "for dir in  $(find #{@apt_repo_path}/#{@pe_version}/repos/el* -type d | grep -v repodata | grep -v cache | xargs)  ; do   pushd $dir; sudo rm -rf repodata; createrepo -q -d .; popd &> /dev/null ; done; sync")
      end

      # This is particularly hacky. The 'pe-the-things' script resides on the @apt_host and takes packages placed
      # in the directory/structure shown in the rsync target of pe:ship_debs and adds them to the remote PE
      # freight repository and updates the apt repo metadata
      desc "remote freight PE packages to #{@apt_host}"
      task :freight => "pl:load_extras" do
        remote_ssh_cmd(@apt_host, "sudo pe-the-things #{@pe_version} #{@apt_repo_path} #{@freight_conf}")
      end
    end
  end
end
