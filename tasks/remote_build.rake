# Tasks for remote building on builder hosts

if File.exist?("#{ENV['HOME']}/.packaging/#{@builder_data_file}")
  namespace 'pl' do
    task :remote_build, :host, :treeish, :task, :tar do |t, args|
      host                    = args.host
      treeish                 = args.treeish
      task                    = args.task
      tar                     = args.tar
      remote_repo             = remote_bootstrap(host, treeish, tar)
      STDOUT.puts "Beginning package build on #{host}"
      remote_ssh_cmd(host, "cd #{remote_repo} ; rake #{task} ANSWER_OVERRIDE=no")
      rsync_from("#{remote_repo}/pkg/", host, 'pkg/')
      remote_ssh_cmd(host, "rm -rf #{remote_repo}")
      STDOUT.puts "packages from #{host} staged in pkg/ directory"
    end

    desc "Execute release_deb_rc full build set on remote debian build host"
    task :remote_deb_rc => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@deb_build_host, 'HEAD', "pl:release_deb_rc COW='#{@cows}'")
    end

    desc "Execute deb_all_rc build on remote debian build host (no signing)"
    task :remote_deb_rc_build => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@deb_build_host, 'HEAD', "pl:deb_all_rc COW='#{@cows}'")
    end

    desc "Execute release_deb_final full build set on remote debian build host"
    task :remote_deb_final => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@deb_build_host, 'HEAD', "pl:release_deb_final COW='#{@cows}'")
    end

    desc "Execute deb_all on remote debian build host (no signing)"
    task :remote_deb_final_build => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@deb_build_host, 'HEAD', "pl:deb_all COW='#{@cows}'")
    end

    desc "Execute release_rpm_rc full build set on remote rpm build host"
    task :remote_rpm_rc => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pl:release_rpm_rc MOCK='#{@rc_mocks}'")
    end

    desc "Execute mock_rc on remote rpm build host (no signing)"
    task :remote_rpm_rc_build => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pl:mock_rc MOCK='#{@rc_mocks}'")
    end

    desc "Execute release_rpm_final full build set on remote rpm build host"
    task :remote_rpm_final => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pl:release_rpm_final MOCK='#{@final_mocks}'")
    end

    desc "Execute mock_final on remote rpm build host (no signing)"
    task :remote_mock_final => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pl:mock_final MOCK='#{@final_mocks}'")
    end

    desc "Execute pl:ips on remote ips build host"
    task :remote_ips => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@ips_build_host, 'HEAD', 'pl:ips', 'gtar')
    end if @build_ips

    desc "Execute package:apple on remote apple build host"
    task :remote_dmg => ['pl:fetch', 'pl:load_extras'] do
      # Because we use rvmsudo for apple, we end up replicating the :remote_build task
      host                    = @osx_build_host
      treeish                 = 'HEAD'
      task                    = "package:apple"
      remote_repo             = remote_bootstrap(host, treeish)
      puts "Beginning package build on #{host}"
      remote_ssh_cmd(host, "cd #{remote_repo} ; rvmsudo rake #{task}")
      rsync_from("#{remote_repo}/pkg/apple", host, 'pkg/')
      remote_ssh_cmd(host, "sudo rm -rf #{remote_repo}")
      STDOUT.puts "packages from #{host} staged in pkg/ directory"
    end if @build_dmg

    desc "UBER RC build: build and ship RC tar, gem (as applicable), remote dmg, remote deb, remote rpm"
    task :uber_rc do
      Rake::Task["package:gem"].invoke if @build_gem
      Rake::Task["pl:remote_deb_rc"].invoke
      Rake::Task["pl:remote_rpm_rc"].execute
      Rake::Task["pl:remote_dmg"].execute if @build_dmg
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote_freight_devel"].invoke
      Rake::Task["pl:remote_update_yum_repo"].invoke
    end

    desc "UBER FINAL build: build and ship FINAL tar, gem (as applicable), remote dmg, remote deb, remote rpm"
    task :uber_final do
      Rake::Task["package:gem"].invoke if @build_gem
      Rake::Task["pl:remote_deb_final"].invoke
      Rake::Task["pl:remote_rpm_final"].execute
      Rake::Task["pl:remote_dmg"].execute if @build_dmg
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote_freight_final"].invoke
      Rake::Task["pl:remote_update_yum_repo"].invoke
    end
  end
end
