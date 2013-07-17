# For PE, the natural default tasks are the remote tasks, rather than
# the local ones, in reflection of which will be most ideal for PE devs.
# e.g., pe:local_deb is the task to build a deb on the local host,
# while pe:deb is the task for building on the remote builder host

if @build.build_pe
  namespace :pe do
    desc "Execute remote debian build using default cow on builder and retrieve package"
    task :deb => 'pl:fetch' do
      ENV['PE_VER'] ||= @build.pe_version
      check_var('PE_VER', ENV['PE_VER'])
      Rake::Task["pl:remote:build"].reenable
      Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pe:local_deb PE_BUILD=#{@build.build_pe} TEAM=#{@build.team} PE_VER=#{ENV['PE_VER']}")
    end

    desc "Execute remote debian build using ALL cows on builder and retrieve packages"
    task :deb_all => 'pl:fetch' do
      ENV['PE_VER'] ||= @build.pe_version
      check_var('PE_VER', ENV['PE_VER'])
      Rake::Task["pl:remote:build"].reenable
      Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pe:local_deb_all PE_BUILD=#{@build.build_pe} COW='#{@build.cows}' TEAM=#{@build.team} PE_VER=#{ENV['PE_VER']}")
    end

    desc "Execute remote rpm build using default mock on builder and retrieve package"
    task :mock => 'pl:fetch' do
      ENV['PE_VER'] ||= @build.pe_version
      Rake::Task["pl:remote:build"].reenable
      Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pe:local_mock PE_BUILD=#{@build.build_pe} TEAM=#{@build.team} PE_VER=#{ENV['PE_VER']}")
    end

    desc "Execute remote rpm build with ALL mocks on builder and retrieve packages"
    task :mock_all => 'pl:fetch' do
      ENV['PE_VER'] ||= @build.pe_version
      Rake::Task["pl:remote:build"].reenable
      Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pe:local_mock_all PE_BUILD=#{@build.build_pe} MOCK='#{@build.final_mocks}' TEAM=#{@build.team} PE_VER=#{ENV['PE_VER']}")
    end

    desc "Execute remote debian, and el builds, sign, and ship pkgs"
    task :all => ['clean', 'pl:fetch'] do
      ['pe:deb_all', 'pe:mock_all', 'pe:ship_rpms', 'pe:ship_debs'].each do |task|
        Rake::Task[task].execute
      end
    end
  end
end

