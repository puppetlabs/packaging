def prep_rpm_build_dir
  temp = Pkg::Util::File.mktemp
  mkdir_pr temp, "#{temp}/SOURCES", "#{temp}/SPECS"
  cp_pr FileList["pkg/#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz*"], "#{temp}/SOURCES"
  Pkg::Util::File.erb_file "ext/redhat/#{Pkg::Config.project}.spec.erb", "#{temp}/SPECS/#{Pkg::Config.project}.spec", nil, :binding => Pkg::Config.get_binding
  temp
end

def build_rpm(buildarg = "-bs")
  Pkg::Util::Tool.check_tool('rpmbuild')
  workdir = prep_rpm_build_dir
  if dist = Pkg::Util::Version.el_version
    if dist.to_i < 6
      dist_string = "--define \"%dist .el#{dist}"
    end
  end
  rpm_define = "#{dist_string} --define \"%_topdir  #{workdir}\" "
  rpm_old_version = '--define "_source_filedigest_algorithm 1" --define "_binary_filedigest_algorithm 1" \
     --define "_binary_payload w9.gzdio" --define "_source_payload w9.gzdio" \
     --define "_default_patch_fuzz 2"'
  args = rpm_define + ' ' + rpm_old_version
  mkdir_pr 'pkg/srpm'
  if buildarg == '-ba'
    mkdir_p 'pkg/rpm'
  end
  if Pkg::Config.sign_tar
    Rake::Task["pl:sign_tar"].invoke
  end
  sh "rpmbuild #{args} #{buildarg} --nodeps #{workdir}/SPECS/#{Pkg::Config.project}.spec"
  mv FileList["#{workdir}/SRPMS/*.rpm"], "pkg/srpm"
  if buildarg == '-ba'
    mv FileList["#{workdir}/RPMS/*/*.rpm"], "pkg/rpm"
  end
  rm_rf workdir
  puts
  output = FileList['pkg/*/*.rpm']
  puts "Wrote:"
  output.each do | line |
    puts line
  end
end

namespace :package do
  desc "Create srpm from this git repository (unsigned)"
  task :srpm => :tar do
    build_rpm("-bs")
  end

  desc "Create .rpm from this git repository (unsigned)"
  task :rpm => :tar do
    build_rpm("-ba")
  end
end

