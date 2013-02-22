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
  end
end
