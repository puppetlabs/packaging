# Tasks for remote building on builder hosts

if File.exist?("#{ENV['HOME']}/.packaging")
  namespace 'pl' do
    namespace :remote do
      task :build, :host, :treeish, :task, :tar do |t, args|
        fail_on_dirty_source
        host                    = args.host
        treeish                 = args.treeish
        task                    = args.task
        tar                     = args.tar
        remote_repo             = remote_bootstrap(host, treeish, tar)
        build_params            = remote_buildparams(host, @build)
        STDOUT.puts "Beginning package build on #{host}"
        remote_ssh_cmd(host, "cd #{remote_repo} ; rake #{task} PARAMS_FILE=#{build_params} ANSWER_OVERRIDE=no PGUSER=#{ENV['PGUSER']} PGDATABASE=#{ENV['PGDATABASE']} PGHOST=#{ENV['PGHOST']}")
        rsync_from("#{remote_repo}/pkg/", host, 'pkg/')
        remote_ssh_cmd(host, "rm -rf #{remote_repo}")
        remote_ssh_cmd(host, "rm #{build_params}")
        STDOUT.puts "packages from #{host} staged in pkg/ directory"
      end

      task :remote_deb_rc => 'pl:fetch' do
        deprecate("pl:remote_deb_rc", "pl:remote:release_deb")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pl:release_deb_rc")
      end

      task :remote_deb_rc_build => 'pl:fetch' do
        deprecate("pl:remote_deb_rc_build", "pl:remote:deb_all")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pl:deb_all_rc")
      end

      task :remote_deb_final => 'pl:fetch' do
        deprecate("pl:remote_deb_final", "pl:remote:release_deb")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pl:release_deb_final")
      end

      task :remote_deb_final_build => 'pl:fetch' do
        deprecate("pl:remote_deb_final_build", "pl:remote:deb_all")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pl:deb_all")
      end

      task :deb => 'pl:fetch' do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pl:deb")
      end

      task :deb_all => 'pl:fetch' do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pl:deb_all")
      end

      task :release_deb => 'pl:fetch'  do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pl:release_deb")
      end

      task :remote_rpm_rc => 'pl:fetch' do
        deprecate("pl:remote_rpm_rc", "pl:remote:release_rpm")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pl:release_rpm_rc")
      end

      task :remote_rpm_rc_build => 'pl:fetch' do
        deprecate("pl:remote_rpm_rc_build", "pl:remote:mock_all")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pl:mock_rc")
      end

      task :remote_rpm_final => 'pl:fetch' do
        deprecate("pl:remote_rpm_final", "pl:remote:release_rpm")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pl:release_rpm_final")
      end

      task :release_rpm => 'pl:fetch' do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pl:release_rpm")
      end

      task :remote_mock_final => 'pl:fetch' do
        deprecate("pl:remote_mock_final", "pl:remote:mock_all")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pl:mock_final")
      end

      task :mock => 'pl:fetch' do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pl:mock")
      end

      task :mock_all => 'pl:fetch' do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pl:mock_all")
      end

      task :ips => 'pl:fetch' do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.ips_build_host, 'HEAD', 'pl:ips', 'gtar')
      end if @build.build_ips

      task :dmg => 'pl:fetch' do
        # Because we use rvmsudo for apple, we end up replicating the :remote_build task
        host                    = @build.osx_build_host
        treeish                 = 'HEAD'
        task                    = "package:apple"
        remote_repo             = remote_bootstrap(host, treeish)
        build_params            = remote_buildparams(host, @build)
        puts "Beginning package build on #{host}"
        remote_ssh_cmd(host, "cd #{remote_repo} ; rvmsudo rake #{task} PARAMS_FILE=#{build_params} PGUSER=#{ENV['PGUSER']} PGDATABASE=#{ENV['PGDATABASE']} PGHOST=#{ENV['PGHOST']}")
        rsync_from("#{remote_repo}/pkg/apple", host, 'pkg/')
        remote_ssh_cmd(host, "sudo rm -rf #{remote_repo}")
        STDOUT.puts "packages from #{host} staged in pkg/ directory"
      end if @build.build_dmg
    end # remote namespace

    task :uber_rc do
      deprecate("pl:uber_rc", "pl:uber_release")
      Rake::Task["package:gem"].invoke if @build.build_gem
      Rake::Task["pl:remote_deb_rc"].invoke
      Rake::Task["pl:remote_rpm_rc"].execute
      Rake::Task["pl:remote:dmg"].execute if @build.build_dmg
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote:freight"].invoke
      Rake::Task["pl:remote:update_yum_repo"].invoke
    end

    task :uber_final do
      deprecate("pl:uber_final", "pl:uber_release")
      Rake::Task["package:gem"].invoke if @build.build_gem
      Rake::Task["pl:remote_deb_final"].invoke
      Rake::Task["pl:remote_rpm_final"].execute
      Rake::Task["pl:remote:dmg"].execute if @build.build_dmg
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote:freight"].invoke
      Rake::Task["pl:remote:update_yum_repo"].invoke
    end

    task :uber_release do
      Rake::Task["package:gem"].invoke if @build.build_gem
      Rake::Task["pl:remote:release_deb"].invoke
      Rake::Task["pl:remote:release_rpm"].execute
      Rake::Task["pl:remote:dmg"].execute if @build.build_dmg
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote:freight"].invoke
      Rake::Task["pl:remote:update_yum_repo"].invoke
    end
  end
end
