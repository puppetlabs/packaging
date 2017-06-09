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
def mock_artifact(mock_config, cmd_args, mockfile)
  unless mock = Pkg::Util::Tool.find_tool('mock')
    raise "mock is required for building srpms with mock. Please install mock and try again."
  end
  randomize = Pkg::Config.random_mockroot
  configdir = nil
  basedir = File.join('var', 'lib', 'mock')

  if randomize
    basedir, configdir = randomize_mock_config_dir(mock_config, mockfile)
    configdir_arg = " --configdir #{configdir}"
  end
  result_dir = Pkg::Util::File.mktemp
  resultdir_arg = " --resultdir #{result_dir}"

  begin
    sh "#{mock} -r #{mock_config} #{resultdir_arg} #{configdir_arg} #{cmd_args}"

    # Return a FileList of the build artifacts
    return FileList[File.join(result_dir, '*.rpm')]

  rescue RuntimeError => error
    build_log = File.join(result_dir, 'build.log')
    root_log  = File.join(result_dir, 'root.log')
    content   = File.read(build_log) if File.readable?(build_log)

    if File.readable?(root_log)
      $stderr.puts File.read(root_log)
    end
    if content and content.lines.count > 2
      $stderr.puts content
    end

    # Any useful info has now been gleaned from the logs in the case of a
    # failure, so we can safely remove basedir if this is a randomized mockroot
    # build. Scarily enough, because of mock permissions, we can't actually
    # just remove it, we have to sudo remove it.

    if randomize and basedir and File.directory?(basedir)
      sh "sudo -n rm -r #{basedir}"
      sh "sudo -n rm -r #{result_dir}"
    end

    raise error
  ensure
    # Unlike basedir, which we keep in the success case, we don't need
    # configdir anymore either way, so we always clean it up if we're using
    # randomized mockroots.
    #
    rm_r configdir if randomize
  end
end

# Use mock to build an SRPM
# Return the path to the srpm
def mock_srpm(mock_config, spec, sources, mockfile, defines = nil)
  cmd_args = "--buildsrpm #{defines} --sources #{sources} --spec #{spec}"
  srpms = mock_artifact(mock_config, cmd_args, mockfile)

  unless srpms.size == 1
    fail "#{srpms} contains an unexpected number of artifacts."
  end
  srpms[0]
end

# Use mock to build rpms from an srpm
# Return a FileList containing the built RPMs
def mock_rpm(mock_config, srpm, mockfile)
  cmd_args = " #{srpm}"
  mock_artifact(mock_config, cmd_args, mockfile)
end

# Determine the "family" of the target distribution based on the mock config name,
# e.g. pupent-3.0-el5-i386 = "el"
# and  pl-fedora-17-i386 = "fedora"
#
def mock_el_family(mock_config)
  if Pkg::Config.build_pe
    # This uses a regex capture instead of splitting to allow the now defunct PE version component to be optional
    family = mock_config.match(/^pupent-(\d\.\d-)?([a-z]+)([0-9]+)-(.*)$/)[2]
  else
    first, second = mock_config.split('-')
    if first == 'el' || first == 'fedora'
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

# Determine the major version of the target distribution based on the mock config name,
# e.g. pupent-3.0-el5-i386 = "5"
# and "pl-fedora-17-i386" = "17"
#
def mock_el_ver(mock_config)
  if Pkg::Config.build_pe
    # This uses a regex capture instead of splitting to allow the now defunct PE version component to be optional
    version = mock_config.match(/^pupent-(\d\.\d-)?([a-z]+)([0-9]+)-(.*)$/)[3]
  else
    first, second, third = mock_config.split('-')
    if (first == 'el' || first == 'fedora') || (first == 'pl' && second.match(/^\d+$/))
      version = second
    else
      version = third
    end
  end
  if [first, second].include?('fedora')
    version = "f#{version}"
  end
  version
end

# Return the RPM family and version for a Vanagon or Packaging repo built project.
def rpm_family_and_version
  if Pkg::Config.vanagon_project
    Pkg::Config.rpm_targets.split(' ').map do |target|
      rpm_el_family, rpm_el_version, arch = target.split('-')
      "#{rpm_el_family}-#{rpm_el_version}"
    end
  else
    Pkg::Config.final_mocks.split.map { |mock| "#{mock_el_family(mock)}-#{mock_el_ver(mock) }" }
  end
end


# Checks to see if the pe agnostic config template is in place.
# If it is then the mock config is set to point to the generated config file.
# The generated config file is formed by substituting the pe_version into the erb
#
def mock_template(mock_config)
  Pkg::Util.check_var("PE version, ENV[PE_VER]", Pkg::Config.pe_version)
  # pe_version is used in the erb template
  pe_version = Pkg::Config.pe_version
  # This bit is fun, here we remove any x.y version in the PE version location in the string from the mock_config
  # for example, pupent-3.4-el5-i386.cfg would become pupent-el5-i386 while pupent-el7-x86_64 would remain unmodified.
  template = mock_config.sub(/([^-]*)-\d\.\d-([^-]*)-([^-]*)/, '\1-\2-\3')
  template_location = File.join(File::SEPARATOR, "etc", "mock", "#{template}.cfg.erb")
  if File.exists?(template_location)
    return template, Pkg::Util::File.erb_file(template_location, nil, false, { :binding => binding })
  else
    return mock_config
  end
end

# Determine the appropriate rpm macro definitions based on the mock config name
# Return a string of space separated macros prefixed with --define
#
def mock_defines(mock_config)
  family = mock_el_family(mock_config)
  version = mock_el_ver(mock_config)
  defines = ""
  if version =~ /^(4|5)$/ or family == "sles"
    defines = %Q(--define "dist .#{family}#{version}" \
      --define "_source_filedigest_algorithm 1" \
      --define "_binary_filedigest_algorithm 1" \
      --define "_binary_payload w9.gzdio" \
      --define "_source_payload w9.gzdio" \
      --define "_default_patch_fuzz 2")
  end
  defines
end

def build_rpm_with_mock(mocks)
  mocks.split(' ').each do |mock_config|
    family  = mock_el_family(mock_config)
    version = mock_el_ver(mock_config)
    subdir  = if Pkg::Config.repo_name
                Pkg::Config.repo_name
              else
                Pkg::Util::Version.final? ? 'products' : 'devel'
              end
    bench = Benchmark.realtime do
      # Set up the rpmbuild dir in a temp space, with our tarball and spec
      workdir = prep_rpm_build_dir
      spec = Dir.glob(File.join(workdir, "SPECS", "*.spec"))[0]
      sources = File.join(workdir, "SOURCES")
      defines = mock_defines(mock_config)
      if Pkg::Config.build_pe
        mock_config, mockfile = mock_template(mock_config)
      end
      # Build the srpm inside a mock chroot
      srpm = mock_srpm(mock_config, spec, sources, mockfile, defines)

      # Now that we have the srpm, build the rpm in a mock chroot
      rpms = mock_rpm(mock_config, srpm, mockfile)

      rpms.each do |rpm|
        rpm.strip!

        if Pkg::Config.build_pe
          %x(mkdir -p pkg/pe/rpm/#{family}-#{version}-{srpms,i386,x86_64})
          case File.basename(rpm)
            when /debuginfo/
              rm_rf(rpm)
            when /src\.rpm/
              FileUtils.cp_r(rpm, "pkg/pe/rpm/#{family}-#{version}-srpms", { :preserve => true })
            when /i.?86/
              FileUtils.cp_r(rpm, "pkg/pe/rpm/#{family}-#{version}-i386", { :preserve => true })
            when /x86_64/
              FileUtils.cp_r(rpm, "pkg/pe/rpm/#{family}-#{version}-x86_64", { :preserve => true })
            when /noarch/
              FileUtils.cp_r(rpm, "pkg/pe/rpm/#{family}-#{version}-i386", { :preserve => true })
              FileUtils.ln("pkg/pe/rpm/#{family}-#{version}-i386/#{File.basename(rpm)}", "pkg/pe/rpm/#{family}-#{version}-x86_64/", :force => true, :verbose => true)
          end
        elsif subdir == 'PC1' || !Pkg::Config.yum_repo_name
          %x(mkdir -p pkg/#{family}/#{version}/#{subdir}/{SRPMS,i386,x86_64})
          case File.basename(rpm)
            when /debuginfo/
              rm_rf(rpm)
            when /src\.rpm/
              FileUtils.cp_r(rpm, "pkg/#{family}/#{version}/#{subdir}/SRPMS", { :preserve => true })
            when /i.?86/
              FileUtils.cp_r(rpm, "pkg/#{family}/#{version}/#{subdir}/i386", { :preserve => true })
            when /x86_64/
              FileUtils.cp_r(rpm, "pkg/#{family}/#{version}/#{subdir}/x86_64", { :preserve => true })
            when /noarch/
              FileUtils.cp_r(rpm, "pkg/#{family}/#{version}/#{subdir}/i386", { :preserve => true })
              FileUtils.ln("pkg/#{family}/#{version}/#{subdir}/i386/#{File.basename(rpm)}", "pkg/#{family}/#{version}/#{subdir}/x86_64/", :force => true, :verbose => true)
          end
        else
          %x(mkdir -p pkg/#{subdir}/#{family}/#{version}/{SRPMS,i386,x86_64})
          case File.basename(rpm)
            when /debuginfo/
              rm_rf(rpm)
            when /src\.rpm/
              FileUtils.cp_r(rpm, "pkg/#{subdir}/#{family}/#{version}/SRPMS", { :preserve => true })
            when /i.?86/
              FileUtils.cp_r(rpm, "pkg/#{subdir}/#{family}/#{version}/i386", { :preserve => true })
            when /x86_64/
              FileUtils.cp_r(rpm, "pkg/#{subdir}/#{family}/#{version}/x86_64", { :preserve => true })
            when /noarch/
              FileUtils.cp_r(rpm, "pkg/#{subdir}/#{family}/#{version}/i386", { :preserve => true })
              FileUtils.ln("pkg/#{subdir}/#{family}/#{version}/i386/#{File.basename(rpm)}", "pkg/#{subdir}/#{family}/#{version}/x86_64/", :force => true, :verbose => true)
          end
        end
      end
      # To avoid filling up the system with our random mockroots, we should
      # clean up. However, this requires sudo. If we don't have sudo, we'll
      # just fail and not clean up, but warn the user about it.
      if Pkg::Config.random_mockroot
        %x(sudo -n echo 'Cleaning build root.')
        if $?.success?
          sh "sudo -n rm -r #{File.dirname(srpm)}" unless File.dirname(srpm).nil?
          sh "sudo -n rm -r #{File.dirname(rpms[0])}" unless File.dirname(rpms[0]).nil?
          sh "sudo -n rm -r #{workdir}" unless workdir.nil?
        else
          warn "Couldn't clean rpm build areas without sudo. Leaving."
        end
      end
    end
    puts "Finished building in: #{bench}"
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
  tempdir = Pkg::Util::File.mktemp
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
  tempdir = Pkg::Util::File.mktemp
  cp File.join('/', 'etc', 'mock', 'site-defaults.cfg'), tempdir
  cp File.join('/', 'etc', 'mock', 'logging.ini'), tempdir
  cp mock, tempdir
  tempdir
end

# Create a mock config file from an existing one, except insert the 'basedir'
# option. 'basedir' will be set to a random directory we create. Move the new
# mock config and the required default mock settings files into a new config
# dir to pass to mock. Return the path to the config dir.
#
def randomize_mock_config_dir(mock_config, mockfile)
  # basedir will be the location of our temporary mock root
  basedir = Pkg::Util::File.mktemp
  chown("#{ENV['USER']}", "mock", basedir)
  # Mock requires the sticky bit be set on the basedir
  chmod(02775, basedir)
  mockfile ||= File.join('/', 'etc', 'mock', "#{mock_config}.cfg")
  puts "Setting mock basedir to #{basedir}"
  # Create a new mock config file with 'basedir' set to our basedir
  config = mock_with_basedir(mockfile, basedir)
  # Setup a mock config dir, copying in our mock config and logging.ini etc
  configdir = setup_mock_config_dir(config)
  # Clean up the directory with the temporary mock config
  rm_r File.dirname(config)
  return basedir, configdir
end


namespace :pl do
  desc "Use default mock to make a final rpm, keyed to PL infrastructure, pass MOCK to specify config"
  task :mock => "package:tar" do
    # If default mock isn't specified, just take the first one in the Pkg::Config.final_mocks list
    Pkg::Config.default_mock ||= Pkg::Config.final_mocks.split(' ')[0]
    build_rpm_with_mock(Pkg::Config.default_mock)
  end

  desc "Use specified mocks to make rpms, keyed to PL infrastructure, pass MOCK to specifiy config"
  task :mock_all => "package:tar" do
    build_rpm_with_mock(Pkg::Config.final_mocks)
  end
end
