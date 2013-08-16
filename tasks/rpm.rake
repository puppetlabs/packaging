def prep_rpm_build_dir
  temp = get_temp
  mkdir_pr temp, "#{temp}/SOURCES", "#{temp}/SPECS"
  cp_pr FileList["pkg/#{@build.project}-#{@build.version}.tar.gz*"], "#{temp}/SOURCES"
  erb "ext/redhat/#{@build.project}.spec.erb", "#{temp}/SPECS/#{@build.project}.spec"
  temp
end

def build_rpm(buildarg = "-bs")
  bench = Benchmark.realtime do
    check_tool('rpmbuild')
    workdir = prep_rpm_build_dir
    if dist = el_version
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
    if @build.sign_tar
      Rake::Task["pl:sign_tar"].invoke
    end
    sh "rpmbuild #{args} #{buildarg} --nodeps #{workdir}/SPECS/#{@build.project}.spec"
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
  add_metrics({ :package_type => 'rpm', :package_build_time => bench }) if @build.is_jenkins_build == false
  post_metrics if @build.is_jenkins_build == false
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

