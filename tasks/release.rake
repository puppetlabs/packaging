# These tasks are "release" chains that couple as much of the release process for a package as possible

namespace :pl do
  task :release_gem do
    Pkg::Util::RakeUtils.invoke_task("package:gem")
    if confirm_ship(FileList["pkg/*.gem"])
      Pkg::Util::RakeUtils.invoke_task("pl:ship_gem")
    end
  end if Pkg::Config.build_gem

  task :release_deb_rc do
    deprecate("pl:release_deb_rc", "pl:release_deb")
    Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
    Pkg::Util::RakeUtils.invoke_task("pl:deb_all_rc")
    Pkg::Util::RakeUtils.invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      Pkg::Util::RakeUtils.invoke_task("pl:ship_debs")
    end
  end

  task :release_deb_final do
    deprecate("pl:release_deb_final", "pl:release_deb")
    Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
    Pkg::Util::RakeUtils.invoke_task("pl:deb_all")
    Pkg::Util::RakeUtils.invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      Pkg::Util::RakeUtils.invoke_task("pl:ship_debs")
    end
  end

  task :release_deb do
    Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
    Pkg::Util::RakeUtils.invoke_task("pl:deb_all")
    Pkg::Util::RakeUtils.invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      Pkg::Util::RakeUtils.invoke_task("pl:ship_debs")
    end
  end

  task :release_rpm_rc do
    deprecate("pl:release_rpm_rc", "pl:release_rpm")
    Pkg::Util::RakeUtils.invoke_task("pl:mock_rc")
    Pkg::Util::RakeUtils.invoke_task("pl:sign_rpms")
    if confirm_ship(FileList["pkg/el/**/*", "pkg/fedora/**/*"])
      Pkg::Util::RakeUtils.invoke_task("pl:ship_rpms")
      Pkg::Util::RakeUtils.invoke_task("pl:remote:update_yum_repo")
    end
  end

  task :release_rpm_final do
    deprecate("pl:release_rpm_final", "pl:release_rpm")
    Pkg::Util::RakeUtils.invoke_task("pl:mock_final")
    Pkg::Util::RakeUtils.invoke_task("pl:sign_rpms")
    if confirm_ship(FileList["pkg/el/**/*", "pkg/fedora/**/*"])
      Pkg::Util::RakeUtils.invoke_task("pl:ship_rpms")
      Pkg::Util::RakeUtils.invoke_task("pl:remote:update_yum_repo")
    end
  end

  task :release_rpm do
    Pkg::Util::RakeUtils.invoke_task("pl:mock_all")
    Pkg::Util::RakeUtils.invoke_task("pl:sign_rpms")
    if confirm_ship(FileList["pkg/el/**/*", "pkg/fedora/**/*"])
      Pkg::Util::RakeUtils.invoke_task("pl:ship_rpms")
      Pkg::Util::RakeUtils.invoke_task("pl:remote:update_yum_repo")
    end
  end

  if File.exist?("#{ENV['HOME']}/.packaging")
    task :release_tar => 'pl:fetch' do
      Pkg::Util::RakeUtils.invoke_task("package:tar")
      Pkg::Util::RakeUtils.invoke_task("pl:sign_tar")
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
      Rake::Task['pl:sign_ips'].invoke
      Rake::Task['pl:remote:update_ips_rep'].invoke
      Rake::Task['pl:ship_p5p'].invoke
    end
  end
end

