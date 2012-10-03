# These tasks are "release" chains that couple as much of the release process for a package as possible

namespace :pl do
  desc "Release gem, e.g. package:gem, pl:ship_gem"
  task :release_gem do
    invoke_task("package:gem")
    if confirm_ship(FileList["pkg/*.gem"])
      invoke_task("pl:ship_gem")
    end
  end if @build_gem

  desc "Release deb RCs, e.g. package:tar, pl:{deb_all_rc, sign_deb_changes, ship_debs}"
  task :release_deb_rc do
    load_keychain if has_tool('keychain')
    invoke_task("pl:deb_all_rc")
    invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      invoke_task("pl:ship_debs")
    end
  end

  desc "Release deb FINALs, e.g. package:tar, pl:{deb_all, sign_deb_changes, ship_debs}"
  task :release_deb_final do
    load_keychain if has_tool('keychain')
    invoke_task("pl:deb_all")
    invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      invoke_task("pl:ship_debs")
    end
  end

  desc "Release rpm RCs, e.g. package:tar, pl:{mock_rc, sign_rpms, ship_rpms, update_yum_repo}"
  task :release_rpm_rc do
    invoke_task("pl:mock_rc")
    invoke_task("pl:sign_rpms")
    if confirm_ship(FileList["pkg/el/**/*", "pkg/fedora/**/*"])
      invoke_task("pl:ship_rpms")
      invoke_task("pl:update_yum_repo")
    end
  end

  desc "Release rpm FINALs, e.g. package:tar, pl:{mock_final, sign_rpms, ship_rpms, update_yum_repo}"
  task :release_rpm_final do
    invoke_task("pl:mock_final")
    invoke_task("pl:sign_rpms")
    if confirm_ship(FileList["pkg/el/**/*", "pkg/fedora/**/*"])
      invoke_task("pl:ship_rpms")
      invoke_task("pl:update_yum_repo")
    end
  end

  if File.exist?("#{ENV['HOME']}/.packaging/#{@builder_data_file}")
    desc "Release tarball, e.g. package:tar, pl:{sign_tar, ship_tar}"
    task :release_tar => :fetch do
      invoke_task("package:tar")
      invoke_task("pl:sign_tar")
      if confirm_ship(FileList["pkg/*tar.gz*"])
        Rake::Task["pl:ship_tar"].execute
      end
    end

    desc "Release dmg, e.g. package:apple, pl:ship_dmg"
    task :release_dmg => :fetch do
      sh "rvmsudo rake package:apple"
      if confirm_ship(FileList["pkg/apple/*.dmg"])
        Rake::Task["pl:ship_dmg"].execute
      end
    end if @build_dmg
  end
end



