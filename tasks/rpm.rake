def build_rpm(buildarg = "-bs")
  check_tool('rpmbuild')
  temp = get_temp
  if dist = el_version
    if dist.to_i < 6
      dist_string = "--define \"%dist .el#{dist}"
    end
  end
  rpm_define = "#{dist_string} --define \"%_topdir  #{temp}\" "
  rpm_old_version = '--define "_source_filedigest_algorithm 1" --define "_binary_filedigest_algorithm 1" \
     --define "_binary_payload w9.gzdio" --define "_source_payload w9.gzdio" \
     --define "_default_patch_fuzz 2"'
  args = rpm_define + ' ' + rpm_old_version
  mkdir_pr temp, 'pkg/srpm', "#{temp}/SOURCES", "#{temp}/SPECS"
  if buildarg == '-ba'
    mkdir_p 'pkg/rpm'
  end
  if @sign_tar
    Rake::Task["pl:sign_tar"].invoke
    cp_p "pkg/#{@name}-#{@version}.tar.gz.asc", "#{temp}/SOURCES"
  end
  cp_p "pkg/#{@name}-#{@version}.tar.gz", "#{temp}/SOURCES"
  erb "ext/redhat/#{@name}.spec.erb", "#{temp}/SPECS/#{@name}.spec"
  sh "rpmbuild #{args} #{buildarg} --nodeps #{temp}/SPECS/#{@name}.spec"
  mv FileList["#{temp}/SRPMS/*.rpm"], "pkg/srpm"
  if buildarg == '-ba'
    mv FileList["#{temp}/RPMS/*/*.rpm"], "pkg/rpm"
  end
  rm_rf temp
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

