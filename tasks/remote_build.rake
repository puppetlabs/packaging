# Tasks for remote building on builder hosts

if File.exist?("#{ENV['HOME']}/.packaging")
  namespace 'pl' do
    namespace :remote do
      task :build, :host, :treeish, :task, :tar do |t, args|
        host                    = args.host
        treeish                 = args.treeish
        task                    = args.task
        tar                     = args.tar
        remote_repo             = remote_bootstrap(host, treeish, tar)
        STDOUT.puts "Beginning package build on #{host}"
        remote_ssh_cmd(host, "cd #{remote_repo} ; rake #{task} ANSWER_OVERRIDE=no PGUSER=#{ENV['PGUSER']} PGDATABASE=#{ENV['PGDATABASE']} PGHOST=#{ENV['PGHOST']}")
        rsync_from("#{remote_repo}/pkg/", host, 'pkg/')
        remote_ssh_cmd(host, "rm -rf #{remote_repo}")
        STDOUT.puts "packages from #{host} staged in pkg/ directory"
      end

      task :remote_deb_rc => ['pl:fetch', 'pl:load_extras'] do
        deprecate("pl:remote_deb_rc", "pl:remote:release_deb")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@deb_build_host, 'HEAD', "pl:release_deb_rc #{@deb_env}")
      end

      task :remote_deb_rc_build => ['pl:fetch', 'pl:load_extras'] do
        deprecate("pl:remote_deb_rc_build", "pl:remote:deb_all")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@deb_build_host, 'HEAD', "pl:deb_all_rc #{@deb_env}")
      end

      task :remote_deb_final => ['pl:fetch', 'pl:load_extras'] do
        deprecate("pl:remote_deb_final", "pl:remote:release_deb")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@deb_build_host, 'HEAD', "pl:release_deb_final #{@deb_env}")
      end

      task :remote_deb_final_build => ['pl:fetch', 'pl:load_extras'] do
        deprecate("pl:remote_deb_final_build", "pl:remote:deb_all")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@deb_build_host, 'HEAD', "pl:deb_all #{@deb_env}")
      end

      desc "Execute pl:deb (single default cow deb package) on remote debian build host (no signing)"
      task :deb => ['pl:fetch', 'pl:load_extras'] do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@deb_build_host, 'HEAD', "pl:deb")
      end

      desc "Execute pl:deb_all on remote debian build host (no signing)"
      task :deb_all => ['pl:fetch', 'pl:load_extras'] do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@deb_build_host, 'HEAD', "pl:deb_all #{@deb_env}")
      end

      desc "Execute remote pl:release_deb_all full build set on remote debian build host"
      task :release_deb => ['pl:fetch', 'pl:load_extras']  do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@deb_build_host, 'HEAD', "pl:release_deb #{@deb_env}")
      end

      task :remote_rpm_rc => ['pl:fetch', 'pl:load_extras'] do
        deprecate("pl:remote_rpm_rc", "pl:remote:release_rpm")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@rpm_build_host, 'HEAD', "pl:release_rpm_rc #{@mockrc_env}")
      end

      task :remote_rpm_rc_build => ['pl:fetch', 'pl:load_extras'] do
        deprecate("pl:remote_rpm_rc_build", "pl:remote:mock_all")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@rpm_build_host, 'HEAD', "pl:mock_rc #{@mockrc_env}")
      end

      task :remote_rpm_final => ['pl:fetch', 'pl:load_extras'] do
        deprecate("pl:remote_rpm_final", "pl:remote:release_rpm")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@rpm_build_host, 'HEAD', "pl:release_rpm_final #{@mockf_env}")
      end

      desc "Execute remote pl:release_rpm full build set on remote rpm build host"
      task :release_rpm => ['pl:fetch', 'pl:load_extras'] do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@rpm_build_host, 'HEAD', "pl:release_rpm #{@mockf_env}")
      end

      task :remote_mock_final => ['pl:fetch', 'pl:load_extras'] do
        deprecate("pl:remote_mock_final", "pl:remote:mock_all")
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@rpm_build_host, 'HEAD', "pl:mock_final #{@mockf_env}")
      end

      desc "Execute pl:mock (single default mock package) on remote rpm build host (no signing)"
      task :mock => ['pl:fetch', 'pl:load_extras'] do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@rpm_build_host, 'HEAD', "pl:mock")
      end

      desc "Execute pl:mock_all on remote rpm build host (no signing)"
      task :mock_all => ['pl:fetch', 'pl:load_extras'] do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@rpm_build_host, 'HEAD', "pl:mock_all #{@mockf_env}")
      end

      desc "Execute pl:ips on remote ips build host"
      task :ips => ['pl:fetch', 'pl:load_extras'] do
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@ips_build_host, 'HEAD', 'pl:ips', 'gtar')
      end if @build_ips

      desc "Execute package:apple on remote apple build host"
      task :dmg => ['pl:fetch', 'pl:load_extras'] do
        # Because we use rvmsudo for apple, we end up replicating the :remote_build task
        host                    = @osx_build_host
        treeish                 = 'HEAD'
        task                    = "package:apple"
        remote_repo             = remote_bootstrap(host, treeish)
        puts "Beginning package build on #{host}"
        remote_ssh_cmd(host, "cd #{remote_repo} ; rvmsudo rake #{task} PGUSER=#{ENV['PGUSER']} PGDATABASE=#{ENV['PGDATABASE']} PGHOST=#{ENV['PGHOST']}")
        rsync_from("#{remote_repo}/pkg/apple", host, 'pkg/')
        remote_ssh_cmd(host, "sudo rm -rf #{remote_repo}")
        STDOUT.puts "packages from #{host} staged in pkg/ directory"
      end if @build_dmg
    end # remote namespace

    task :uber_rc do
      deprecate("pl:uber_rc", "pl:uber_release")
      Rake::Task["package:gem"].invoke if @build_gem
      Rake::Task["pl:remote_deb_rc"].invoke
      Rake::Task["pl:remote_rpm_rc"].execute
      Rake::Task["pl:remote:dmg"].execute if @build_dmg
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote:freight"].invoke
      Rake::Task["pl:remote:update_yum_repo"].invoke
    end

    task :uber_final do
      deprecate("pl:uber_final", "pl:uber_release")
      Rake::Task["package:gem"].invoke if @build_gem
      Rake::Task["pl:remote_deb_final"].invoke
      Rake::Task["pl:remote_rpm_final"].execute
      Rake::Task["pl:remote:dmg"].execute if @build_dmg
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote:freight"].invoke
      Rake::Task["pl:remote:update_yum_repo"].invoke
    end

    desc "UBER build: build, sign and ship tar, gem (as applicable), remote dmg, remote deb, remote rpm"
    task :uber_release do
      Rake::Task["package:gem"].invoke if @build_gem
      Rake::Task["pl:remote:release_deb"].invoke
      Rake::Task["pl:remote:release_rpm"].execute
      Rake::Task["pl:remote:dmg"].execute if @build_dmg
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote:freight"].invoke
      Rake::Task["pl:remote:update_yum_repo"].invoke
    end
  end
end
