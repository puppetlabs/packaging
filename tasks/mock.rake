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
  check_tool('mock')
  sh "mock -r #{mock_config} #{srpm}"
end

def srpm_file
  srpm = Dir["pkg/srpm/*.rpm"][0]
  check_file(srpm)
  srpm
end

def mock_el_family(mock_config)
  if @build_pe
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
  if @build_pe
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

def mock_arch(mock_config)
  if @build_pe
    arch = mock_config.split('-')[3]
  else
    arch = mock_config.split('-')[2]
  end
end

def build_rpm_with_mock(mocks, is_rc)
  mocks.split(' ').each do |mock_config|
    family  = mock_el_family(mock_config)
    version = mock_el_ver(mock_config)
    arch    = mock_arch(mock_config)
    subdir  = is_rc ? 'devel' : 'products'
    bench = Benchmark.realtime do
      result  = "/var/lib/mock/#{mock_config}/result/*.rpm"
      mock(mock_config, srpm_file)

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

        if @build_pe
          case File.basename(rpm)
            when /debuginfo/
              rm_rf(rpm)
            when /src\.rpm/
              cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-srpms")
            when /i.?86/
              cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-i386")
            when /x66_64/
              cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-x86_64")
            when /noarch/
              cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-i386")
              ln("pkg/pe/rpm/#{family}-#{version}-i386/#{File.basename(rpm)}", "pkg/pe/rpm/#{family}-#{version}-x86_64/")
          end
        else
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
    end
    add_metrics({ :dist => "#{family}-#{version}", :bench => bench }) if @benchmark
  end
end


namespace :pl do
  task :setup_el_dirs do
    if @build_pe
      %x{mkdir -p pkg/pe/rpm/sles-11-{i586,x86_64,srpms}}
      %x{mkdir -p pkg/pe/rpm/el-{5,6}-{i386,x86_64,srpms}}
    else
      %x{mkdir -p pkg/el/{5,6}/{products,devel,dependencies}/{SRPMS,i386,x86_64}}
      %x{mkdir -p pkg/fedora/{f16,f17}/{products,devel,dependencies}/{SRPMS,i386,x86_64}}
    end
  end

  desc "Use default mock to make a final rpm, keyed to PL infrastructure, pass MOCK to specify config"
  task :mock => [ "package:srpm", "pl:setup_el_dirs" ] do
    # If default mock isn't specified, just take the first one in the @final_mocks list
    @default_mock ||= @final_mocks.split(' ')[0]
    build_rpm_with_mock(@default_mock, is_rc?)
    post_metrics if @benchmark
  end

  task :mock_final => [ "package:srpm", "pl:setup_el_dirs" ] do
    deprecate("pl:mock_final", "pl:mock_all")
    build_rpm_with_mock(@final_mocks, FALSE)
    post_metrics if @benchmark
  end

  task :mock_rc => [ "package:srpm", "pl:setup_el_dirs" ] do
    deprecate("pl:mock_rc", "pl:mock_all")
    build_rpm_with_mock(@rc_mocks, TRUE)
    post_metrics if @benchmark
  end

  desc "Use specified mocks to make rpms, keyed to PL infrastructure, pass MOCK to specifiy config"
  task :mock_all => [ "package:srpm", "pl:setup_el_dirs" ] do
    build_rpm_with_mock(@final_mocks, is_rc?)
    post_metrics if @benchmark
  end
end
