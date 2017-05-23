def prep_rpm_build_dir
  temp = Pkg::Util::File.mktemp
  tarball = "#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz"
  FileUtils.mkdir_p([temp, "#{temp}/SOURCES", "#{temp}/SPECS"])
  FileUtils.cp_r FileList["pkg/#{tarball}*"], "#{temp}/SOURCES", { :preserve => true }
  # If the file ext/redhat/<project>.spec exists in the tarball, we use it. If
  # it doesn't we try to 'erb' the file from a predicted template in source,
  # ext/redhat/<project>.spec.erb. If that doesn't exist, we fail. To do this,
  # we have to open the tarball.
  FileUtils.cp("pkg/#{tarball}", temp, { :preserve => true })

  # Test for specfile in tarball
  %x(tar -tzf #{File.join(temp, tarball)}).split.grep(/\/ext\/redhat\/#{Pkg::Config.project}.spec$/)

  if $?.success?
    sh "tar -C #{temp} -xzf #{File.join(temp, tarball)} #{Pkg::Config.project}-#{Pkg::Config.version}/ext/redhat/#{Pkg::Config.project}.spec"
    cp("#{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}/ext/redhat/#{Pkg::Config.project}.spec", "#{temp}/SPECS/")
  elsif File.exists?("ext/redhat/#{Pkg::Config.project}.spec.erb")
    Pkg::Util::File.erb_file("ext/redhat/#{Pkg::Config.project}.spec.erb", "#{temp}/SPECS/#{Pkg::Config.project}.spec", nil, :binding => Pkg::Config.get_binding)
  else
    fail "Could not locate redhat spec ext/redhat/#{Pkg::Config.project}.spec or ext/redhat/#{Pkg::Config.project}.spec.erb"
  end
  temp
end

def build_rpm(buildarg = "-bs")
  Pkg::Util::Tool.check_tool('rpmbuild')
  workdir = prep_rpm_build_dir
  rpm_define = "--define \"%_topdir  #{workdir}\" "
  rpm_old_version = '--define "_source_filedigest_algorithm 1" --define "_binary_filedigest_algorithm 1" \
     --define "_binary_payload w9.gzdio" --define "_source_payload w9.gzdio" \
     --define "_default_patch_fuzz 2"'
  args = rpm_define + ' ' + rpm_old_version
  FileUtils.mkdir_p('pkg/srpm')
  if buildarg == '-ba'
    FileUtils.mkdir_p('pkg/rpm')
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

