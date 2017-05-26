require 'pathname'

def pdebuild(args)
  results_dir = args[:work_dir]
  cow         = args[:cow]
  Pkg::Deb.set_cow_envs(cow)
  update_cow(cow)
  sh "pdebuild  --configfile #{Pkg::Config.pbuild_conf} \
                --buildresult #{results_dir} \
                --pbuilder cowbuilder -- \
                --basepath /var/cache/pbuilder/#{cow}/"
  $?.success? or fail "Failed to build deb with #{cow}!"
end

def update_cow(cow)
  ENV['PATH'] = "/usr/sbin:#{ENV['PATH']}"
  Pkg::Deb.set_cow_envs(cow)
  Pkg::Util::Execution.retry_on_fail(:times => 3) do
    sh "sudo -E /usr/sbin/cowbuilder --update --override-config --configfile #{Pkg::Config.pbuild_conf} --basepath /var/cache/pbuilder/#{cow} --distribution #{ENV['DIST']} --architecture #{ENV['ARCH']}"
  end
end

def debuild(args)
  results_dir = args[:work_dir]
  begin
    sh "debuild --no-lintian -uc -us"
  rescue => e
    fail "Something went wrong. Hopefully the backscroll or #{results_dir}/#{Pkg::Config.project}_#{Pkg::Config.debversion}.build file has a clue.\n#{e}"
  end
end

task :prep_deb_tars, :work_dir do |t, args|
  work_dir = args.work_dir
  FileUtils.cp "pkg/#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz", work_dir, { :preserve => true }
  cd work_dir do
    sh "tar zxf #{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz"
    mv "#{Pkg::Config.project}-#{Pkg::Config.version}", "#{Pkg::Config.project}-#{Pkg::Config.debversion}"
    mv "#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz", "#{Pkg::Config.project}_#{Pkg::Config.origversion}.orig.tar.gz"
  end


  # This assumes that work_dir is absolute, which I hope is a safe assumption.
  #
  # Also, it turns out that invoking 'find' on a directory that doesn't exist
  # will fail in nasty ways, so we only do this if the target exists...
  if Pathname('ext/debian').directory?
    pkg_dir = "#{work_dir}/#{Pkg::Config.project}-#{Pkg::Config.debversion}"
    cd 'ext' do
      Pathname('debian').find do |file|
        case
        when file.to_s =~ /~$/, file.to_s =~ /^#/
          next
        when file.directory?
          mkdir_p "#{pkg_dir}/#{file}"
        when file.extname == '.erb'
          Pkg::Util::File.erb_file(file, "#{pkg_dir}/#{file.sub(/\.[^\.]*$/, '')}", false, :binding => Pkg::Config.get_binding)
        else
          cp file, "#{pkg_dir}/#{file}"
        end
      end
    end
  end
end

task :build_deb, :deb_command, :cow do |t, args|
  subrepo = Pkg::Config.repo_name
  bench = Benchmark.realtime do
    deb_build = args.deb_command
    cow       = args.cow
    work_dir  = Pkg::Util::File.mktemp
    subdir    = 'pe/' if Pkg::Config.build_pe
    codename = /base-(.*)-(.*)\.cow/.match(cow)[1] unless cow.nil?
    dest_dir  = File.join(Pkg::Config.project_root, "pkg", "#{subdir}deb", codename, subrepo.to_s)
    Pkg::Util::Tool.check_tool(deb_build)
    mkdir_p dest_dir
    deb_args  = { :work_dir => work_dir, :cow => cow }
    Rake::Task[:prep_deb_tars].reenable
    Rake::Task[:prep_deb_tars].invoke(work_dir)
    cd "#{work_dir}/#{Pkg::Config.project}-#{Pkg::Config.debversion}" do
      if !File.directory?('debian') and File.directory?('ext/debian')
        mv 'ext/debian', 'debian'
      end

      # So this is terrible. It is a hacky hacky bandaid for until this can be
      # totally refactored into a library with templates drawn entirely from
      # the tarball. The following two lines are needed because the deb.rake
      # logic currently re-templates all of the templates in ext/debian for use
      # in packaging. Then, before the package is built, if the debian
      # directory doesn't exist (this is really only the case for puppetdb),
      # the ext/debian directory from the tarball is moved into place. This
      # breaks ezbake because ezbake maps templates to differently named files
      # in the tarball templating, but those newly generated templates are
      # completely ignored without the following two lines that unconditionally
      # copy anything in ext/debian into the debian directory.
      mkdir_p 'debian'
      FileUtils.cp_r(Dir.glob("ext/debian/*"), 'debian', { :preserve => true })
      send(deb_build, deb_args)
      cp FileList["#{work_dir}/*.deb", "#{work_dir}/*.dsc", "#{work_dir}/*.changes", "#{work_dir}/*.debian.tar.gz", "#{work_dir}/*.orig.tar.gz", "${work_dir}/*.diff.gz"], dest_dir
      rm_rf "#{work_dir}/#{Pkg::Config.project}-#{Pkg::Config.debversion}"
      rm_rf work_dir
    end
  end
  puts "Finished building in: #{bench}"
end

namespace :package do
  desc "Create a deb from this repo, using debuild (all builddeps must be installed)"
  task :deb => :tar do
    Rake::Task[:build_deb].invoke('debuild')
  end
end

namespace :pl do
  desc "Create a deb from this repo using the default cow #{Pkg::Config.default_cow}."
  task :deb => "package:tar"  do
    Pkg::Util.check_var('PE_VER', Pkg::Config.pe_version) if Pkg::Config.build_pe
    Rake::Task[:build_deb].invoke('pdebuild', Pkg::Config.default_cow)
  end

  desc "Create debs from this git repository using all cows specified in build_defaults yaml"
  task :deb_all do
    Pkg::Util.check_var('PE_VER', Pkg::Config.pe_version) if Pkg::Config.build_pe
    Pkg::Config.cows.split(' ').each do |cow|
      Rake::Task["package:tar"].invoke
      Rake::Task[:build_deb].reenable
      Rake::Task[:build_deb].invoke('pdebuild', cow)
    end
  end
end
