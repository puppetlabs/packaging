
def mock(mock_config, srpm)
  check_tool('mock')
  %x{mock -r #{mock_config} #{srpm}}
end

def srpm_file
  srpm = Dir["pkg/srpm/*.rpm"][0]
  check_file(srpm)
  srpm
end

def mock_el_family(mock_config)
  family = mock_config.split('-')[0]
  family = 'el' if family == 'pl'
  family
end

def mock_el_ver(mock_config)
  version = mock_config.split('-')[1]
  version = "f#{version}" if mock_config.split('-')[0] == 'fedora'
  version
end

def build_rpm_with_mock(is_rc, subdir)
  if is_rc
    mocks = @rc_mocks
  else
    mocks = @final_mocks
  end

  mocks.split(' ').each do |mock_config|
    family  = mock_el_family mock_config
    version = mock_el_ver mock_config
    arch    = mock_config.split('-')[2]
    result  = "/var/lib/mock/#{mock_config}/result/*.rpm"

    mock mock_config, srpm_file

    Dir[result].each do |rpm|
      rpm.strip!

      if is_rc == FALSE and rpm =~ /[0-9]+rc[0-9]+\./
        puts "It looks like you might be trying to ship an RC to the production repos. Leaving rpm in #{result}"
        next
      elsif is_rc and rpm !~ /[0-9]+rc[0-9]+\./
        puts "It looks like you might be trying to ship a production release to the development repos. Leaving rpm in #{result}"
        next
      end

      case rpm
        when /debuginfo/
          rm_rf rpm
        when /src\.rpm/
          cp_pr rpm, "pkg/#{family}/#{version}/#{subdir}/SRPMS"
        when /i.?86/
          cp_pr rpm, "pkg/#{family}/#{version}/#{subdir}/i386"
        when /x86_64/
          cp_pr rpm, "pkg/#{family}/#{version}/#{subdir}/x86_64"
        when /noarch/
          cp_pr rpm, "pkg/#{family}/#{version}/#{subdir}/i386"
          ln "pkg/#{family}/#{version}/#{subdir}/i386/#{File.basename rpm}", "pkg/#{family}/#{version}/#{subdir}/x86_64/"
      end
    end
  end
end


namespace :pl do
  task :setup_el_dirs do
    %x{mkdir -p pkg/el/{5,6}/{products,devel,dependencies}/{SRPMS,i386,x86_64}}
    %x{mkdir -p pkg/fedora/{f15,f16,f17}/{products,devel,dependencies}/{SRPMS,i386,x86_64}}
  end

  desc "Use specified mocks to make final rpms, keyed to Puppet Labs infrastructure, pass MOCK to specifiy config"
  task :mock_final => [ "package:srpm", "pl:setup_el_dirs" ] do
    subdir = ENV['subdir'] || 'products'
    build_rpm_with_mock(FALSE, subdir)
  end

  desc "Use specified mocks to make RC rpms, keyed to Puppet Labs infrastructure, pass MOCK to specify config"
  task :mock_rc => [ "package:srpm", "pl:setup_el_dirs" ] do
    subdir = 'devel'
    build_rpm_with_mock(TRUE, subdir)
  end
end

