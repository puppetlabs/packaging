def build_rpm(buildarg = "-bs")
  check_tool('rpmbuild')
  temp = get_temp
  rpm_define = "--define \"%dist .el5\" --define \"%_topdir  #{temp}\" "
  rpm_old_version = '--define "_source_filedigest_algorithm 1" --define "_binary_filedigest_algorithm 1" \
     --define "_binary_payload w9.gzdio" --define "_source_payload w9.gzdio" \
     --define "_default_patch_fuzz 2"'
  args = rpm_define + ' ' + rpm_old_version
  mkdir_pr temp, 'pkg/rpm', 'pkg/srpm', "#{temp}/SOURCES", "#{temp}/SPECS"
  if @sign_srpm
    gpg_sign_file "pkg/#{@name}-#{@version}.tar.gz"
    cp_p "pkg/#{@name}-#{@version}.tar.gz.asc", "#{temp}/SOURCES"
  end
  cp_p "pkg/#{@name}-#{@version}.tar.gz", "#{temp}/SOURCES"
  erb "ext/redhat/#{@name}.spec.erb", "#{temp}/SPECS/#{@name}.spec"
  sh "rpmbuild #{args} #{buildarg} --nodeps #{temp}/SPECS/#{@name}.spec"
  output = `find #{temp} -name *.rpm`
  mv FileList["#{temp}/SRPMS/*.rpm"], "pkg/srpm"
  mv FileList["#{temp}/RPMS/*/*.rpm"], "pkg/rpm"
  rm_rf temp
  puts
  puts "Wrote:"
  output.each_line do | line |
    puts "#{`pwd`.strip}/pkg/rpm/#{line.split('/')[-1]}"
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

