if Pkg::Config.build_pe
  namespace :pe do
    desc "Sign all staged in rpms in pkg"
    task :sign_rpms do
      Pkg::Util::RakeUtils.invoke_task("pl:sign_rpms")
    end

    desc "Sign all debian changes files staged in pkg/pe"
    task :sign_deb_changes do
      Pkg::Util::RakeUtils.invoke_task("pl:sign_deb_changes")
    end
  end
end
