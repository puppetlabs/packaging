# The sign_legacy_rpm and sign_rpm methods are defined in sign.rake
# This is just adapted for the 'PE' layout

if Pkg::Config.build_pe
  namespace :pe do
    desc "Sign all staged in rpms in pkg"
    task :sign_rpms do
      old_rpms = FileList.new
      modern_rpms = FileList.new
      # Find x86_64 noarch rpms that have been created as hard links and remove them
      rm_r Dir["pkg/pe/rpm/*-*-x86_64/*.noarch.rpm"]
      # We'll sign the remaining noarch
      sign_dists = [
      { :OS => 'el', :version => 4 },
      { :OS => 'el', :version => 5 },
      { :OS => 'el', :version => 6 },
      { :OS => 'el', :version => 7 },
      { :OS => 'sles', :version => 10 },
      { :OS => 'sles', :version => 11 },
      { :OS => 'sles', :version => 12 }
      ]
      ['i386', 'x86_64'].each do |arch|
        sign_dists.each do |dist|
          family = dist[:OS]
          version = dist[:version]
          rpm_stagedir        = "pkg/pe/rpm/#{family}-#{version}-#{arch}/*.rpm"
          srpm_stagedir       = "pkg/pe/rpm/#{family}-#{version}-srpms/*.rpm"
          if (family == 'el' and version >= 6) || (family == 'sles' and version >= 12)
            modern_rpms += FileList[rpm_stagedir] + FileList[srpm_stagedir]
          else
            old_rpms += FileList[rpm_stagedir] + FileList[srpm_stagedir]
          end
        end
      end
      sign_legacy_rpm(old_rpms) unless old_rpms.empty?
      sign_rpm(modern_rpms) unless modern_rpms.empty?
      # Now we hardlink them back in
      Dir["pkg/pe/rpm/*-*-i386/*.noarch.rpm"].each do |rpm|
        dir = rpm.split('/')[-2]
        family, version, _arch = dir.split('-')
        cd File.dirname(rpm) do
          FileUtils.ln(File.basename(rpm), File.join('..', "#{family}-#{version}-x86_64"), :force => true, :verbose => true)
        end
      end
    end
    # This is essentially a duplicate of the logic in pl:sign_deb_changes, but
    # since the plan is eventually to rip out the PE work, it'll be easier if
    # this is a separate task we can pull out later.
    desc "Sign all debian changes files staged in pkg/pe"
    task :sign_deb_changes do
      Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
      sign_deb_changes("pkg/pe/deb/*/*.changes") unless Dir["pkg/pe/deb/*/*.changes"].empty?
    end
  end
end
