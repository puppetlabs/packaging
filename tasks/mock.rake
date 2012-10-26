
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
    family = mock_config.split('-')[0]
    family = 'el' if family == 'pl'
  end
  family
end

def mock_el_ver(mock_config)
  if @build_pe
    version = mock_config.split('-')[2][/[0-9]+/]
  else
    version = mock_config.split('-')[1]
    version = "f#{version}" if mock_config.split('-')[0] == 'fedora'
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

def build_rpm_with_mock(mocks, is_rc, subdir)
  mocks.split(' ').each do |mock_config|
    family  = mock_el_family(mock_config)
    version = mock_el_ver(mock_config)
    arch    = mock_arch(mock_config)
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
end


namespace :pl do
  task :setup_el_dirs do
    if @build_pe
      %x{mkdir -p pkg/pe/rpm/el-{5,6}-{i386,x86_64,srpms}}
    else
      %x{mkdir -p pkg/el/{5,6}/{products,devel,dependencies}/{SRPMS,i386,x86_64}}
      %x{mkdir -p pkg/fedora/{f15,f16,f17}/{products,devel,dependencies}/{SRPMS,i386,x86_64}}
    end
  end

  task :setup_sles_dirs do
      %x{mkdir -p pkg/pe/sles-11-{i386,x86_64,srpms}}
  end

  desc "Use default mock to make a final rpm, keyed to PL infrastructure, pass MOCK to specify config"
  task :mock => [ "package:srpm", "pl:setup_el_dirs" ] do
    # If default mock isn't specified, just take the first one in the @final_mocks list
    @default_mock ||= @final_mocks.split(' ')[0]
    subdir = ENV['subdir'] || 'products'
    build_rpm_with_mock(@default_mock, FALSE, subdir)
  end

  desc "Use specified mocks to make final rpms, keyed to PL infrastructure, pass MOCK to specifiy config"
  task :mock_final => [ "package:srpm", "pl:setup_el_dirs" ] do
    subdir = ENV['subdir'] || 'products'
    build_rpm_with_mock(@final_mocks, FALSE, subdir)
  end

  desc "Use specified mocks to make RC rpms, keyed to PL infrastructure, pass MOCK to specify config"
  task :mock_rc => [ "package:srpm", "pl:setup_el_dirs" ] do
    subdir = 'devel'
    build_rpm_with_mock(@rc_mocks, TRUE, subdir)
  end
end
