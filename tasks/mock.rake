# The mock methods/tasks are fairly specific to puppetlabs infrastructure, e.g., the mock configs
# have to be named in a format like the PL mocks, e.g. dist-version-architecture, such as:
# el-5-i386
# fedora-17-i386
# as well as the oddly formatted exception, 'pl-5-i386' which is the default puppetlabs FOSS mock
# format for 'el-5-i386' (note swap 'pl' for 'el')
#
# The mock-built rpms are placed in a directory structure under 'pkg' based on how the Puppet Labs
# repo structure is laid out in order to facilitate easy shipping from the local repository to the
# Puppet Labs repos. For open source, the directory structure mirrors that of yum.puppetlabs.com:
# pkg/<dist>/<version>/{products,devel,dependencies}/<arch>/*.rpm
# e.g.,
# pkg/el/5/products/i386/*.rpm
# pkg/fedora/f16/products/i386/*.rpm
#
# For PE, the directory structure is flatter:
# pkg/<dist>-<version>-<arch>/*.rpm
# e.g.,
# pkg/el-5-i386/*.rpm

def mock(mock_config, srpm)
  configdir = nil
  unless mock = find_tool('mock')
    warn "mock is required for building rpms with mock. Please install mock and try again."
    exit 1
  end
  if @build.random_mockroot
    basedir = get_temp
    chown("#{ENV['USER']}", "mock", basedir)
    # Mock requires the sticky bit be set on the basedir
    chmod(02775, basedir)
    mockfile = File.join('/', 'etc', 'mock', "#{mock_config}.cfg")
    puts "Setting mock basedir to #{basedir}"
    config = mock_with_basedir(mockfile, basedir)
    configdir = setup_mock_config_dir(config)
    # Clean up the new mock config
    rm_r  File.dirname(config)
    configdir_arg = " --configdir #{configdir}"
    mock << configdir_arg
  end
  sh "#{mock} -r #{mock_config} #{srpm}"
  # Clean up the configdir
  rm_r configdir unless configdir.nil?

  basedir
end

def srpm_file
  srpm = Dir["pkg/srpm/*.rpm"][0]
  check_file(srpm)
  srpm
end

def mock_el_family(mock_config)
  if @build.build_pe
    family = mock_config.split('-')[2][/[a-z]+/]
  else
    first, second = mock_config.split('-')
    if (first == 'el' || first == 'fedora')
      family = first
    elsif first == 'pl'
      if second.match(/^\d+$/)
        family = 'el'
      else
        family = second
      end
    end
  end
  family
end

def mock_el_ver(mock_config)
  if @build.build_pe
    version = mock_config.split('-')[2][/[0-9]+/]
  else
    first, second, third = mock_config.split('-')
    if (first == 'el' || first == 'fedora') || (first == 'pl' && second.match(/^\d+$/))
      version = second
    else
      version = third
    end
  end
  if [first,second].include?('fedora')
    version = "f#{version}"
  end
  version
end

def build_rpm_with_mock(mocks, is_rc)
  mocks.split(' ').each do |mock_config|
    family  = mock_el_family(mock_config)
    version = mock_el_ver(mock_config)
    subdir  = is_rc ? 'devel' : 'products'
    bench = Benchmark.realtime do
      resultdir = mock(mock_config, srpm_file)
      result  = "#{resultdir}/#{mock_config}/result/*.rpm"

      Dir[result].each do |rpm|
        rpm.strip!
        unless ENV['RC_OVERRIDE'] == '1'
          if is_rc == FALSE and rpm =~ /[0-9]+rc[0-9]+\./
            puts "It looks like you might be trying to ship an RC to the production repos. Leaving rpm in #{result}. Pass RC_OVERRIDE=1 to override."
            next
          elsif is_rc and rpm !~ /[0-9]+rc[0-9]+\./
            puts "It looks like you might be trying to ship a production release to the development repos. Leaving rpm in #{result}. Pass RC_OVERRIDE=1 to override."
            next
          end
        end

        if @build.build_pe
          %x{mkdir -p pkg/pe/rpm/#{family}-#{version}-{srpms,i386,x86_64}}
          case File.basename(rpm)
            when /debuginfo/
              rm_rf(rpm)
            when /src\.rpm/
              cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-srpms")
            when /i.?86/
              cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-i386")
            when /x86_64/
              cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-x86_64")
            when /noarch/
              cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-i386")
              ln("pkg/pe/rpm/#{family}-#{version}-i386/#{File.basename(rpm)}", "pkg/pe/rpm/#{family}-#{version}-x86_64/")
          end
        else
          %x{mkdir -p pkg/#{family}/#{version}/#{subdir}/{SRPMS,i386,x86_64}}
          case File.basename(rpm)
            when /debuginfo/
              rm_rf(rpm)
            when /src\.rpm/
              cp_pr(rpm, "pkg/#{family}/#{version}/#{subdir}/SRPMS")
            when /i.?86/
              cp_pr(rpm, "pkg/#{family}/#{version}/#{subdir}/i386")
            when /x86_64/
              cp_pr(rpm, "pkg/#{family}/#{version}/#{subdir}/x86_64")
            when /noarch/
              cp_pr(rpm, "pkg/#{family}/#{version}/#{subdir}/i386")
              ln("pkg/#{family}/#{version}/#{subdir}/i386/#{File.basename(rpm)}", "pkg/#{family}/#{version}/#{subdir}/x86_64/")
          end
        end
      end
      # To avoid filling up the system with our random mockroots, we should
      # clean up. However, this requires sudo. If we don't have sudo, we'll
      # just fail and not clean up, but warn the user about it.
      if @build.random_mockroot
        %x{sudo -n echo 'Cleaning build root.'}
        if $?.success?
          sh "sudo -n rm -r #{resultdir}" unless resultdir.nil?
        else
          warn "Couldn't clean #{resultdir} without sudo. Leaving."
        end
      end
    end
    add_metrics({ :dist => "#{family}-#{version}", :bench => bench }) if @build.benchmark
  end
end

# With the advent of using Jenkins to parallelize builds, it becomes critical
# that we be able to use the same mock at the same time for > 1 builds without
# clobbering the mock root every time. Here we add a method that takes the full
# path to a mock configuration and a path, and adds a base directory
# configuration directive to the mock to use the path as the directory for the
# mock build root. The new mock config is written to a temporary space, and its
# location is returned.  This allows us to create mock configs with randomized
# temporary mock roots.
#
def mock_with_basedir(mock, basedir)
  config = IO.readlines(mock)
  basedir = "config_opts['basedir'] = '#{basedir}'"
  config.unshift(basedir)
  tempdir = get_temp
  newmock = File.join(tempdir, File.basename(mock))
  File.open(newmock, 'w') { |f| f.puts config }
  newmock
end

# Mock accepts an alternate configuration directory to /etc/mock for mock
# configs, but the directory has to include both site-defaults.cfg and
# logging.ini. This is a simple utility method to set a mock configuration dir
# by copying a mock and the required defaults to a temporary directory and
# returning that directory. This method takes the full path to a mock
# configuration file and returns the path to the new configuration dir.
#
def setup_mock_config_dir(mock)
  tempdir = get_temp
  cp File.join('/', 'etc', 'mock', 'site-defaults.cfg'), tempdir
  cp File.join('/', 'etc', 'mock', 'logging.ini'), tempdir
  cp mock, tempdir
  tempdir
end

namespace :pl do
  desc "Use default mock to make a final rpm, keyed to PL infrastructure, pass MOCK to specify config"
  task :mock => "package:srpm" do
    # If default mock isn't specified, just take the first one in the @build.final_mocks list
    @build.default_mock ||= @build.final_mocks.split(' ')[0]
    build_rpm_with_mock(@build.default_mock, is_rc?)
    post_metrics if @build.benchmark
  end

  task :mock_final => "package:srpm" do
    deprecate("pl:mock_final", "pl:mock_all")
    build_rpm_with_mock(@build.final_mocks, FALSE)
    post_metrics if @build.benchmark
  end

  task :mock_rc => "package:srpm" do
    deprecate("pl:mock_rc", "pl:mock_all")
    build_rpm_with_mock(@build.rc_mocks, TRUE)
    post_metrics if @build.benchmark
  end

  desc "Use specified mocks to make rpms, keyed to PL infrastructure, pass MOCK to specifiy config"
  task :mock_all => "package:srpm" do
    build_rpm_with_mock(@build.final_mocks, is_rc?)
    post_metrics if @build.benchmark
  end
end
