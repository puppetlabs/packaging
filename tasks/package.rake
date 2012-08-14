desc "Build various packages"
namespace :package do
  desc "Create .deb from this git repository."
  task :deb => :tar  do
    temp = get_temp
    cp_p "pkg/#{@name}-#{@version}.tar.gz", "#{temp}"
    cd temp do
      sh "tar zxf #{@name}-#{@version}.tar.gz"
      mv "#{@name}-#{@version}", "#{@name}-#{@debversion}"
      mv "#{@name}-#{@version}.tar.gz", "#{@name}_#{@origversion}.orig.tar.gz"
      cd "#{@name}-#{@debversion}" do
        mv File.join('ext', 'debian'), '.'
        build_cmd = "pdebuild --configfile #{@pbuild_conf} --buildresult #{temp} --pbuilder cowbuilder -- --basepath /var/cache/pbuilder/#{@cow}/"
        begin
          sh build_cmd
          dest_dir = File.join(@build_root, 'pkg', 'deb')
          mkdir_p dest_dir
          cp FileList["#{temp}/*.deb", "#{temp}/*.dsc", "#{temp}/*.changes", "#{temp}/*.debian.tar.gz", "#{temp}/*.orig.tar.gz"], dest_dir
          output = `find #{dest_dir}`
          puts
          puts "Wrote:"
          output.each_line do | line |
            puts "#{`pwd`.strip}/pkg/deb/#{line.split('/')[-1]}"
          end
        rescue
          STDERR.puts "Something went wrong. Hopefully the backscroll or #{temp}/#{@name}_#{@debversion}.build file has a clue."
        end
      end
      rm_rf temp
    end
  end

  desc "Create srpm from this git repository (unsigned)"
  task :srpm => :tar do
    build_rpm("-bs")
  end

  desc "Create .rpm from this git repository (unsigned)"
  task :rpm => :tar do
    build_rpm("-ba")
  end

  desc "Create a source tar archive"
  task :tar => [ :clean, :build_environment ] do
    workdir = "pkg/#{@name}-#{@version}"
    mkdir_p workdir
    FileList[ "ext", "CHANGELOG", "COPYING", "README.md", "*.md", "lib", "bin", "spec", "Rakefile", "acceptance_tests" ].each do |f|
      cp_pr f, workdir
    end
    erb "#{workdir}/ext/redhat/#{@name}.spec.erb", "#{workdir}/ext/redhat/#{@name}.spec"
    erb "#{workdir}/ext/debian/changelog.erb", "#{workdir}/ext/debian/changelog"
    rm_rf FileList["#{workdir}/ext/debian/*.erb", "#{workdir}/ext/redhat/*.erb"]
    cd "pkg" do
      sh "tar --exclude=.gitignore -zcf #{@name}-#{@version}.tar.gz #{@name}-#{@version}"
    end
    rm_rf workdir
    puts
    puts "Wrote #{`pwd`.strip}/pkg/#{@name}-#{@version}"
  end

  task :build_environment do
    unless ENV['FORCE'] == '1'
      modified = `git status --porcelain | sed -e '/^\?/d'`
      if modified.split(/\n/).length != 0
        puts <<-HERE
!! ERROR: Your git working directory is not clean. You must
!! remove or commit your changes before you can create a package:

#{`git status | grep '^#'`.chomp}

!! To override this check, set FORCE=1 -- e.g. `rake package:deb FORCE=1`
        HERE
        raise
      end
    end
  end
end
