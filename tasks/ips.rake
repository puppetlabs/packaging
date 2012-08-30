require 'erb'
namespace :package do
  workdir = "ips"
  proto = workdir + '/proto'

  def x(v)
    puts %[#{v}]
    print %x[#{v}]
  end

  desc "Create a source repo"
  task :clean do
    %x[rm -rf #{workdir}]
  end

  desc "Create an installation image at ips/proto"
  task :prepare => [ :clean ] do
    check_tool('pkgsend')
    x %[mkdir -p #{workdir}]
    x %[gmake -f ext/ips/rules 2>#{workdir}/build.out ]
  end

  desc "Process templates and write the initial manifest"
  task :prototmpl => :prepare do
    File.open(workdir + '/' + @name + '.p5m.x', 'w') do |f|
      f.puts ERB.new(File.read('ext/ips/facter.p5m.erb')).result(binding)
    end
  end

  desc "Update manifest to include the installation image information."
  task :protogen => :prototmpl do
    x %[pkgsend generate #{proto} >> #{workdir}/#{@name}.p5m.x ]
    os=%x[uname -p].chomp
  end

  desc "Generate and resolve dependency list"
  task :protodeps => :protogen do
    x %[pkgdepend generate -d #{proto} #{workdir}/#{@name}.p5m.x > #{workdir}/#{@name}.depends ]
    x %[pkgdepend resolve -m #{workdir}/#{@name}.depends ]
    x %[cat #{workdir}/#{@name}.depends.res >> #{workdir}/#{@name}.p5m.x]
  end

  desc "Mogrify manifest to remove unncecessary info, and other kinds of transforms."
  task :protomogrify => :protodeps do
    x %[pkgmogrify ./ext/ips/transforms ./#{workdir}/#{@name}.p5m.x| pkgfmt >> #{workdir}/#{@name}.p5m ]
  end

  desc "Generate and resolve dependency list"
  task :license => :protomogrify do
    x %[cp LICENSE #{proto}/facter.license]
  end

  desc "Ensure that our manifest is sane."
  task :lint => :license do
    x %[pkglint #{workdir}/#{@name}.p5m]
  end

  desc "upload an ips version"
  task :ips => [ :lint ] do
    x %[pkgsend -s #{@ips_repo} publish -d #{proto} #{workdir}/#{@name}.p5m]
  end

  task :ipstest do
    %x[rm #{workdir}/#{@name}.p5p]
    x %[pkgrecv -s #{@ips_repo} -a -d #{workdir}/#{@name}.p5p #{@name}@#{@ipsversion}]
    x %[pkg list -n -g #{workdir}/#{@name}.p5p #{@name}@#{@ipsversion}]
    puts %[pkg install -nv -g #{workdir}/#{@name}.p5p #{@name}@#{@ipsversion}]
  end
end
