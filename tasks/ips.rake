if @build_ips
  namespace :package do
    namespace :ips do
      workdir = "pkg/ips/workdir"
      proto = workdir + '/proto'
      repo = workdir + '/repo'
      pkgs = 'pkg/ips/pkgs'
      repouri = 'file://' + Dir.pwd + '/' + repo
      artifact = pkgs + "/#{@build.project}@#{@build.ipsversion}.p5p"

      # Create a source repo
      # We dont clean the base pkg directory only ips work dir.
      task :clean do
        rm_rf workdir
      end

      task :clean_pkgs do
        rm_rf pkgs
      end

      # Create an installation image at ips/proto
      task :prepare do
        mkdir_pr workdir, pkgs
        sh "gmake -f ext/ips/rules DESTDIR=#{proto} 2>#{workdir}/build.out"
      end

      # Process templates and write the initial manifest
      task :prototmpl do
        Pkg::Util::File.erb_file("ext/ips/#{@build.project}.p5m.erb", workdir + '/' + @build.project + '.p5m.x', nil, :binding => Pkg::Config.get_binding)
      end

      # Update manifest to include the installation image information.
      task :protogen => :prototmpl do
        sh "pkgsend generate #{proto} >> #{workdir}/#{@build.project}.p5m.x"
      end

      # Generate and resolve dependency list
      task :protodeps => :protogen do
        sh "pkgdepend generate -d #{proto} #{workdir}/#{@build.project}.p5m.x > #{workdir}/#{@build.project}.depends"
        sh "pkgdepend resolve -m #{workdir}/#{@build.project}.depends"
        sh "cat #{workdir}/#{@build.project}.depends.res >> #{workdir}/#{@build.project}.p5m.x"
      end

      # Mogrify manifest to remove unncecessary info, and other kinds of transforms.
      task :protomogrify => :protodeps do
        sh "pkgmogrify ./ext/ips/transforms ./#{workdir}/#{@build.project}.p5m.x| pkgfmt >> #{workdir}/#{@build.project}.p5m"
      end

      # Generate and resolve dependency list
      task :license => :protomogrify do
        cp 'LICENSE', "#{proto}/#{@build.project}.license"
      end

      # Ensure that our manifest is sane.
      task :lint => :license do
        print %x{pkglint #{workdir}/#{@build.project}.p5m}
      end

      task :package => [:clean_pkgs, :clean, :prepare, :lint] do
        # the package is actually created via the dependency chain of :lint
      end

      # Create a local file-based IPS repository
      task :createrepo do
        Pkg::Util::Tool.check_tool('pkgrepo')
        sh "pkgrepo create #{repo}"
        sh "pkgrepo set -s #{repo} publisher/prefix=puppetlabs.com"
      end

      # Send a created package to the local IPS repository
      task :send do
        Pkg::Util::Tool.check_tool('pkgsend')
        sh "pkgsend -s #{repouri} publish -d #{proto} --fmri-in-manifest #{workdir}/#{@build.project}.p5m"
      end

      # Retrieve the package from the remote repository in .p5p archive format
      task :receive do
        Pkg::Util::Tool.check_tool('pkgrecv')
        sh "pkgrecv -s #{repouri} -a -d #{artifact} #{@build.project}@#{@build.ipsversion}"
      end


      task :dry_install do
        sh "pkg install -nv -g #{artifact} #{@build.project}@#{@build.ipsversion}"
      end

      task :p5p, :sign_ips do |t, args|
        # make sure our system dependencies are met
        Pkg::Util::Tool.check_tool('pkg')
        Pkg::Util::Tool.check_tool('pkgdepend')
        Pkg::Util::Tool.check_tool('pkgsend')
        Pkg::Util::Tool.check_tool('pkglint')
        Pkg::Util::Tool.check_tool('pkgmogrify')
        sign_ips = args.sign_ips
        # create the package manifest & files (the "package")
        Rake::Task['package:ips:package'].invoke
        # create the local repository
        Rake::Task['package:ips:createrepo'].invoke
        # publish the package to the repository
        Rake::Task['package:ips:send'].invoke
        # signing the package occurs remotely in the repository
        Rake::Task['pl:sign_ips'].invoke(repouri,"#{@build.project}@#{@build.ipsversion}") if sign_ips
        # retrieve the signed package in a .p5p archive file format
        Rake::Task['package:ips:receive'].invoke
        # clean up the workdir area
        Rake::Task['package:ips:clean'].execute
        STDOUT.puts "Created #{Dir['pkg/ips/pkgs/*']}"
      end
    end

    desc "Creates an ips p5p archive package from this repository"
    task :ips => ['package:ips:p5p']
  end

  namespace :pl do
    desc "Create and sign a p5p archive package from this repository"
    task :ips => 'pl:fetch' do
      Rake::Task['package:ips:p5p'].reenable
      Rake::Task['package:ips:p5p'].invoke(TRUE)
    end
  end
end
