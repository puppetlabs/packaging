if @build_ips
  require 'erb'
  namespace :package do
    namespace :ips do
      workdir = "pkg/ips"
      proto = workdir + '/proto'
      repo = workdir + '/repo'
      pkgs = workdir + '/pkgs'
      repouri = "file://#{`pwd`.strip + '/' + repo}"
      artifact = "#{pkgs}/#{@name}@#{@ipsversion}.p5p"

      # Create a source repo
      # We dont clean the base pkg directory only ips work dir.
      task :clean do
        %x[rm -rf #{workdir}]
      end

      # Create an installation image at ips/proto
      task :prepare => :clean do
        check_tool('pkgsend')
        x %[mkdir -p #{workdir}]
        x %[gmake -f ext/ips/rules DESTDIR=#{proto} 2>#{workdir}/build.out ]
      end

      # Process templates and write the initial manifest
      task :prototmpl do
        erb("ext/ips/#{@name}.p5m.erb", workdir + '/' + @name + '.p5m.x')
      end

      # Update manifest to include the installation image information.
      task :protogen => :prototmpl do
        x %[pkgsend generate #{proto} >> #{workdir}/#{@name}.p5m.x ]
        os=%x[uname -p].chomp
      end

      # Generate and resolve dependency list
      task :protodeps => :protogen do
        x %[pkgdepend generate -d #{proto} #{workdir}/#{@name}.p5m.x > #{workdir}/#{@name}.depends ]
        x %[pkgdepend resolve -m #{workdir}/#{@name}.depends ]
        x %[cat #{workdir}/#{@name}.depends.res >> #{workdir}/#{@name}.p5m.x]
      end

      # Mogrify manifest to remove unncecessary info, and other kinds of transforms.
      task :protomogrify => :protodeps do
        x %[pkgmogrify ./ext/ips/transforms ./#{workdir}/#{@name}.p5m.x| pkgfmt >> #{workdir}/#{@name}.p5m ]
      end

      # Generate and resolve dependency list
      task :license => :protomogrify do
        x %[cp LICENSE #{proto}/#{@name}.license]
      end

      # Ensure that our manifest is sane.
      task :lint => :license do
        x %[pkglint #{workdir}/#{@name}.p5m]
      end

      task :package => :lint do
        x %[rm -rf #{pkgs}]
        x %[mkdir -p #{pkgs}]
        x %[pkgrepo create #{repo}]
        x %[pkgrepo set -s #{repo} publisher/prefix=puppetlabs.com]
        x %[pkgsend -s #{repouri} publish -d #{proto} --fmri-in-manifest #{workdir}/#{@name}.p5m]
        x %[rm -f #{artifact}]
        x %[pkgrecv -s #{repouri} -a -d #{artifact} #{@name}@#{@ipsversion}]
       end

      task :dry_install do
        x %[pkg install -nv -g #{artifact} #{@name}@#{@ipsversion}]
      end
    end

    desc "Creates an ips version"
    task :ips do
      Rake::Task['package:ips:prepare'].invoke
      Rake::Task['package:ips:package'].invoke
    end

  end
end
