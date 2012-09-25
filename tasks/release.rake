# These tasks are "release" chains that couple as much of the release process for a package as possible

namespace :pl do
  if @build_gem == TRUE or @build_gem == 'true' or @build_gem == 'TRUE'
    desc "Build and ship a gem"
    task :release_gem do
      invoke_task("package:gem")
      if confirm_ship(FileList["pkg/*.gem"])
        invoke_task("pl:ship_gem")
      end
    end
  end

  desc "Release deb RCs, e.g. package:tar, pl:{deb_all_rc, sign_deb_changes, ship_debs}"
  task :release_deb_rc do
    invoke_task("pl:deb_all_rc")
    invoke_task("pl:sign_deb_changes")
    if confirm_ship(FileList["pkg/deb/**/*"])
      invoke_task("pl:ship_debs")
    end
  end

  desc "Release deb FINALs, e.g. package:tar, pl:{deb_all, sign_deb_changes, ship_debs}"
  task :release_deb_final do
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
end



