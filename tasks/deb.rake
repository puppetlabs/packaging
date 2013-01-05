def pdebuild args
  results_dir = args[:work_dir]
  cow         = args[:cow]
  devel_repo  = args[:devel]
  set_cow_envs(cow)
  update_cow(cow, devel_repo)
  begin
    sh "pdebuild  --configfile #{@pbuild_conf} \
                  --buildresult #{results_dir} \
                  --pbuilder cowbuilder -- \
                  --basepath /var/cache/pbuilder/#{cow}/"
  rescue Exception => e
    puts e
    handle_method_failure('pdebuild', args)
  end
end

def update_cow(cow, is_rc = nil)
  ENV['FOSS_DEVEL'] = is_rc
  ENV['PATH'] = "/usr/sbin:#{ENV['PATH']}"
  set_cow_envs(cow)
  begin
    sh "sudo -E /usr/sbin/cowbuilder --update --override-config --configfile #{@pbuild_conf} --basepath /var/cache/pbuilder/#{cow} --distribution #{ENV['DIST']} --architecture #{ENV['ARCH']}"
  rescue
    STDERR.puts "Couldn't update the cow #{cow}. Perhaps you don't have sudo?"
    exit 1
  end
end

def debuild args
  results_dir = args[:work_dir]
  begin
    sh "debuild --no-lintian -uc -us"
  rescue
    STDERR.puts "Something went wrong. Hopefully the backscroll or #{results_dir}/#{@name}_#{@debversion}.build file has a clue."
    exit 1
  end
end

task :prep_deb_tars, :work_dir do |t,args|
  work_dir = args.work_dir
  cp_p "pkg/#{@name}-#{@version}.tar.gz", work_dir
  cd work_dir do
    sh "tar zxf #{@name}-#{@version}.tar.gz"
    mv "#{@name}-#{@version}", "#{@name}-#{@debversion}"
    mv "#{@name}-#{@version}.tar.gz", "#{@name}_#{@origversion}.orig.tar.gz"
  end
end

task :build_deb, :deb_command, :cow, :devel do |t,args|
  bench = Benchmark.realtime do
    deb_build = args.deb_command
    cow       = args.cow
    devel     = args.devel
    work_dir  = get_temp
    subdir    = 'pe/' if @build_pe
    dest_dir  = "#{@build_root}/pkg/#{subdir}deb/#{cow.split('-')[1] unless cow.nil?}"
    check_tool(deb_build)
    mkdir_p dest_dir
    deb_args  = { :work_dir => work_dir, :cow => cow, :devel => devel}
    Rake::Task[:prep_deb_tars].reenable
    Rake::Task[:prep_deb_tars].invoke(work_dir)
    cd "#{work_dir}/#{@name}-#{@debversion}" do
      mv 'ext/debian', '.'
      send(deb_build, deb_args)
      cp FileList["#{work_dir}/*.deb", "#{work_dir}/*.dsc", "#{work_dir}/*.changes", "#{work_dir}/*.debian.tar.gz", "#{work_dir}/*.orig.tar.gz"], dest_dir
      rm_rf "#{work_dir}/#{@name}-#{@debversion}"
      rm_rf work_dir
    end
  end
  # See 30_metrics.rake to see what this is doing
  add_metrics({ :dist => ENV['DIST'], :bench => bench }) if @benchmark
end

namespace :package do
  desc "Create a deb from this repo, using debuild (all builddeps must be installed)"
  task :deb => :tar do
    Rake::Task[:build_deb].invoke('debuild')
  end
end

namespace :pl do
  desc "Create a deb from this repo using the default cow #{@default_cow}."
  task :deb => "package:tar"  do
    check_var('PE_VER', ENV['PE_VER']) if @build_pe
    Rake::Task[:build_deb].invoke('pdebuild', @default_cow)
    post_metrics if @benchmark
  end

  task :deb_rc => "package:tar" do
    deprecate("pl:deb_rc", "pl:deb")
    Rake::Task[:build_deb].invoke('pdebuild', @default_cow, 'devel')
    post_metrics if @benchmark
  end

  desc "Create debs from this git repository using all cows specified in build_defaults yaml"
  task :deb_all do
    check_var('PE_VER', ENV['PE_VER']) if @build_pe
    @cows.split(' ').each do |cow|
      Rake::Task["package:tar"].invoke
      Rake::Task[:build_deb].reenable
      Rake::Task[:build_deb].invoke('pdebuild', cow)
    end
    post_metrics if @benchmark
  end

  task :deb_all_rc do
    deprecate("pl:deb_all_rc", "pl:deb_all")
    @cows.split(' ').each do |cow|
      Rake::Task["package:tar"].invoke
      Rake::Task[:build_deb].reenable
      Rake::Task[:build_deb].invoke('pdebuild', cow, 'devel')
    end
  end
  post_metrics if @benchmark
end
