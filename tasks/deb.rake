def pdebuild args
  results_dir = args[:work_dir]
  cow         = args[:cow]
  devel_repo  = args[:devel]
  set_cow_envs(cow)
  update_cow(cow, devel_repo)
  begin
    sh "pdebuild  --configfile #{@build.pbuild_conf} \
                  --buildresult #{results_dir} \
                  --pbuilder cowbuilder -- \
                  --basepath /var/cache/pbuilder/#{cow}/"
  rescue Exception => e
    puts e
    handle_method_failure('pdebuild', args)
  end
end

def update_cow(cow, is_rc = nil)
  ENV['FOSS_DEVEL'] = is_rc.to_s
  ENV['PATH'] = "/usr/sbin:#{ENV['PATH']}"
  set_cow_envs(cow)
  retry_on_fail(:times => 3) do
    sh "sudo -E /usr/sbin/cowbuilder --update --override-config --configfile #{@build.pbuild_conf} --basepath /var/cache/pbuilder/#{cow} --distribution #{ENV['DIST']} --architecture #{ENV['ARCH']}"
  end
end

def debuild args
  results_dir = args[:work_dir]
  begin
    sh "debuild --no-lintian -uc -us"
  rescue
    STDERR.puts "Something went wrong. Hopefully the backscroll or #{results_dir}/#{@build.project}_#{@build.debversion}.build file has a clue."
    exit 1
  end
end

task :prep_deb_tars, :work_dir do |t,args|
  work_dir = args.work_dir
  cp_p "pkg/#{@build.project}-#{@build.version}.tar.gz", work_dir
  cd work_dir do
    sh "tar zxf #{@build.project}-#{@build.version}.tar.gz"
    mv "#{@build.project}-#{@build.version}", "#{@build.project}-#{@build.debversion}"
    mv "#{@build.project}-#{@build.version}.tar.gz", "#{@build.project}_#{@build.origversion}.orig.tar.gz"
  end
end

task :build_deb, :deb_command, :cow, :devel do |t,args|
  bench = Benchmark.realtime do
    deb_build = args.deb_command
    cow       = args.cow
    devel     = args.devel
    work_dir  = get_temp
    subdir    = 'pe/' if @build.build_pe
    dest_dir  = "#{@build_root}/pkg/#{subdir}deb/#{cow.split('-')[1] unless cow.nil?}"
    check_tool(deb_build)
    mkdir_p dest_dir
    deb_args  = { :work_dir => work_dir, :cow => cow, :devel => devel}
    Rake::Task[:prep_deb_tars].reenable
    Rake::Task[:prep_deb_tars].invoke(work_dir)
    cd "#{work_dir}/#{@build.project}-#{@build.debversion}" do
      mv 'ext/debian', '.'
      send(deb_build, deb_args)
      cp FileList["#{work_dir}/*.deb", "#{work_dir}/*.dsc", "#{work_dir}/*.changes", "#{work_dir}/*.debian.tar.gz", "#{work_dir}/*.orig.tar.gz"], dest_dir
      rm_rf "#{work_dir}/#{@build.project}-#{@build.debversion}"
      rm_rf work_dir
    end
  end
  # See 30_metrics.rake to see what this is doing
  add_metrics({ :dist => ENV['DIST'], :bench => bench }) if @build.benchmark
end

namespace :package do
  desc "Create a deb from this repo, using debuild (all builddeps must be installed)"
  task :deb => :tar do
    Rake::Task[:build_deb].invoke('debuild')
  end
end

namespace :pl do
  desc "Create a deb from this repo using the default cow #{@build.default_cow}."
  manageable_task :deb => "package:tar" do
    check_var('PE_VER', @build.pe_version) if @build.build_pe
    Rake::Task[:build_deb].invoke('pdebuild', @build.default_cow, is_rc?)
    post_metrics if @build.benchmark
  end

  task :deb_rc => "package:tar" do
    deprecate("pl:deb_rc", "pl:deb")
    Rake::Task[:build_deb].invoke('pdebuild', @build.default_cow, 'true')
    post_metrics if @build.benchmark
  end

  desc "Create debs from this git repository using all cows specified in build_defaults yaml"
  task :deb_all do
    check_var('PE_VER', @build.pe_version) if @build.build_pe
    @build.cows.split(' ').each do |cow|
      Rake::Task["package:tar"].invoke
      Rake::Task[:build_deb].reenable
      Rake::Task[:build_deb].invoke('pdebuild', cow, is_rc?)
    end
    post_metrics if @build.benchmark
  end

  task :deb_all_rc do
    deprecate("pl:deb_all_rc", "pl:deb_all")
    @build.cows.split(' ').each do |cow|
      Rake::Task["package:tar"].invoke
      Rake::Task[:build_deb].reenable
      Rake::Task[:build_deb].invoke('pdebuild', cow, 'true')
    end
  end
  post_metrics if @build.benchmark
end
