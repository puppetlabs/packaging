def build_rpm(buildarg = "-bs")
  begin
    check_tool('rpmbuild')
    temp = get_temp
    if dist = el_version
      if dist.to_i < 6
        dist_string = "--define \"%dist .el#{dist}"
      end
    end
    rpm_define = "#{dist_string} --define \"%_topdir  #{temp}\" "
    puts rpm_define

    rpm_old_version = '--define "_source_filedigest_algorithm 1" --define "_binary_filedigest_algorithm 1" \
       --define "_binary_payload w9.gzdio" --define "_source_payload w9.gzdio" \
       --define "_default_patch_fuzz 2"'
    args = rpm_define + ' ' + rpm_old_version
    mkdir_pr temp, 'pkg/srpm', "#{temp}/SOURCES", "#{temp}/SPECS"
    if buildarg == '-ba'
      mkdir_p 'pkg/rpm'
    end
    if @build.sign_tar
      Rake::Task["pl:sign_tar"].invoke
      cp_p "pkg/#{@build.project}-#{@build.version}.tar.gz.asc", "#{temp}/SOURCES"
    end
    cp_p "pkg/#{@build.project}-#{@build.version}.tar.gz", "#{temp}/SOURCES"
    erb "ext/redhat/#{@build.project}.spec.erb", "#{temp}/SPECS/#{@build.project}.spec"
    sh "rpmbuild #{args} #{buildarg} --nodeps #{temp}/SPECS/#{@build.project}.spec"
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
  rescue Exception => e
    @build_success = false
  end
end

namespace :package do
  desc "Create srpm from this git repository (unsigned)"
  task :srpm => :tar do
    build_rpm("-bs")
  end

  desc "Create .rpm from this git repository (unsigned)"
  task :rpm => :tar do
    bench = Benchmark.realtime do
      begin
        @build_success = true
        build_rpm("-ba")
      rescue Exception => e
        puts e
        @build_success = false
      end
    end
    add_metrics({ :dist => 'rpm', :package_type => 'rpm', :bench => bench, :success => @build_success}) if @build.benchmark
    post_metrics if @build.benchmark
  end
end
