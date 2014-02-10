# These tasks are "release" chains that couple as much of the release process for a package as possible

namespace :pl do
  task :release_gem do
    invoke_task("package:gem")
    if confirm_ship(FileList["pkg/*.gem"])
      invoke_task("pl:ship_gem")
    end
  end if Pkg::Config.build_gem

  task :release_deb_rc do
    deprecate("pl:release_deb_rc", "pl:release_deb")
    load_keychain if Pkg::Util::Tool.find_tool('keychain')
    invoke_task("pl:deb_all_rc")
    invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      invoke_task("pl:ship_debs")
    end
  end

  task :release_deb_final do
    deprecate("pl:release_deb_final", "pl:release_deb")
    load_keychain if Pkg::Util::Tool.find_tool('keychain')
    invoke_task("pl:deb_all")
    invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      invoke_task("pl:ship_debs")
    end
  end

  task :release_deb do
    load_keychain if Pkg::Util::Tool.find_tool('keychain')
    invoke_task("pl:deb_all")
    invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      invoke_task("pl:ship_debs")
    end
  end

  task :release_rpm_rc do
    deprecate("pl:release_rpm_rc", "pl:release_rpm")
    invoke_task("pl:mock_rc")
    invoke_task("pl:sign_rpms")
    if confirm_ship(FileList["pkg/el/**/*", "pkg/fedora/**/*"])
      invoke_task("pl:ship_rpms")
      invoke_task("pl:remote:update_yum_repo")
    end
  end

  task :release_rpm_final do
    deprecate("pl:release_rpm_final", "pl:release_rpm")
    invoke_task("pl:mock_final")
    invoke_task("pl:sign_rpms")
    if confirm_ship(FileList["pkg/el/**/*", "pkg/fedora/**/*"])
      invoke_task("pl:ship_rpms")
      invoke_task("pl:remote:update_yum_repo")
    end
  end

  task :release_rpm do
    invoke_task("pl:mock_all")
    invoke_task("pl:sign_rpms")
    if confirm_ship(FileList["pkg/el/**/*", "pkg/fedora/**/*"])
      invoke_task("pl:ship_rpms")
      invoke_task("pl:remote:update_yum_repo")
    end
  end

  if File.exist?("#{ENV['HOME']}/.packaging")
    task :release_tar => 'pl:fetch' do
      invoke_task("package:tar")
      invoke_task("pl:sign_tar")
      if confirm_ship(FileList["pkg/*tar.gz*"])
        Rake::Task["pl:ship_tar"].execute
      end
    end

    task :release_dmg => 'pl:fetch' do
      sh "rvmsudo rake package:apple"
      if confirm_ship(FileList["pkg/apple/*.dmg"])
        Rake::Task["pl:ship_dmg"].execute
      end
    end if Pkg::Config.build_dmg

    task :release_ips => 'pl:fetch' do
      Rake::Task['pl:ips'].invoke
      Rake::Task['pl:ship_ips'].invoke
    end
  end
end

