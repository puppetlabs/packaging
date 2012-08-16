def pdebuild args
  results_dir = args[:work_dir]
  cow         = args[:cow]
  begin
    sh "pdebuild --configfile #{@pbuild_conf} --buildresult #{results_dir} --pbuilder cowbuilder -- --basepath /var/cache/pbuilder/#{cow}/"
  rescue
    STDERR.puts "Something went wrong. Hopefully the backscroll or #{results_dir}/#{@name}_#{@debversion}.build file has a clue."
  end
end

def debuild args
  results_dir = args[:work_dir]
  begin
    sh "debuild --no-lintian -uc -us"
  rescue
    STDERR.puts "Something went wrong. Hopefully the backscroll or #{results_dir}/#{@name}_#{@debversion}.build file has a clue."
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

task :build_deb, :deb_command, :cow do |t,args|
  deb_build = args.deb_command
  cow       = args.cow
  work_dir  = get_temp
  dest_dir  = "#{@build_root}/pkg/deb/#{cow.split('-')[1] unless cow.nil?}"
  check_tool(deb_build)
  mkdir_p dest_dir
  deb_args  = { :work_dir => work_dir, :cow => cow }
  Rake::Task[:prep_deb_tars].reenable
  Rake::Task[:prep_deb_tars].invoke(work_dir)
  cd "#{work_dir}/#{@name}-#{@debversion}" do
    mv 'ext/debian', '.'
    begin
      send(deb_build, deb_args)
      cp FileList["#{work_dir}/*.deb", "#{work_dir}/*.dsc", "#{work_dir}/*.changes", "#{work_dir}/*.debian.tar.gz", "#{work_dir}/*.orig.tar.gz"], dest_dir
      rm_rf "#{work_dir}/#{@name}-#{@debversion}"
    rescue
      STDERR.puts "Something went wrong. Hopefully the backscroll or #{work_dir}/#{@name}_#{@debversion}.build file has a clue."
    end
    rm_rf work_dir
  end
end

namespace :package do
  desc "Create a deb from this repo, using debuild (all builddeps must be installed)"
  task :deb => :tar do
    Rake::Task[:build_deb].invoke('debuild')
  end
end

namespace :pl do
  desc "Create a deb from this repo using the default cow #{@default_cow}."
  task :deb_cow => "package:tar"  do
    Rake::Task[:build_deb].invoke('pdebuild', @default_cow)
  end

  desc "Create debs from this git repository using all cows specified in build_defaults.yaml"
  task :deb_all_cows do
    @cows.split(' ').each do |cow|
      Rake::Task["package:tar"].invoke
      Rake::Task[:build_deb].reenable
      Rake::Task[:build_deb].invoke('pdebuild', cow)
    end
  end
end

