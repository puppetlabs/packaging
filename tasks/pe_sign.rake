# The sign_el5 and sign_modern methods are defined in sign.rake
# This is just adapted for the 'PE' layout

if @build.build_pe
  namespace :pe do
    desc "Sign all staged in rpms in pkg"
    task :sign_rpms do
      old_rpms = FileList.new
      modern_rpms = FileList.new
      sign_dists = 'el5', 'el6', 'sles11'
      ['i386', 'x86_64'].each do |arch|
        sign_dists.each do |dist|
          family=dist[/[a-z]+/]
          version=dist[/[0-9]+/]
          rpm_stagedir        = "pkg/pe/rpm/#{family}-#{version}-#{arch}/*.rpm"
          srpm_stagedir       = "pkg/pe/rpm/#{family}-#{version}-srpms/*.rpm"
          if family == 'el' and version == '6'
            modern_rpms += FileList[rpm_stagedir] + FileList[srpm_stagedir]
          else
            old_rpms += FileList[rpm_stagedir] + FileList[srpm_stagedir]
          end
        end
      end
      sign_el5(old_rpms) unless old_rpms.empty?
      sign_modern(modern_rpms) unless modern_rpms.empty?
    end
    # This is essentially a duplicate of the logic in pl:sign_deb_changes, but
    # since the plan is eventually to rip out the PE work, it'll be easier if
    # this is a separate task we can pull out later.
    desc "Sign all debian changes files staged in pkg/pe"
    task :sign_deb_changes do
      load_keychain if has_tool('keychain')
      sign_deb_changes("pkg/pe/deb/*/*.changes") unless Dir["pkg/pe/deb/*/*.changes"].empty?
    end
  end
end
