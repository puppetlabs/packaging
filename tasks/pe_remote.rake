if @build_pe
  namespace :pe do
    desc "Execute remote debian build using default cow on builder and retrieve package"
    task :deb => ['pl:fetch', 'pl:load_extras'] do
      ENV['PE_VER'] ||= @pe_version
      check_var('PE_VER', ENV['PE_VER'])
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@deb_build_host, 'HEAD', "pe:local_deb PE_VER=#{ENV['PE_VER']}")
    end

    desc "Execute remote debian build using ALL cows on builder and retrieve packages"
    task :deb_all => ['pl:fetch', 'pl:load_extras'] do
      ENV['PE_VER'] ||= @pe_version
      check_var('PE_VER', ENV['PE_VER'])
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@deb_build_host, 'HEAD', "pe:local_deb_all PE_VER=#{ENV['PE_VER']}")
    end

    desc "Execute remote rpm build using default mock on builder and retrieve package"
    task :mock => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pe:local_mock")
    end

    desc "Execute remote rpm build with ALL mocks on builder and retrieve packages"
    task :mock_all => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pe:local_mock_final")
    end

    desc "Execute remote sles rpm build and retrieve package"
    task :sles => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@sles_build_host, 'HEAD', "pe:local_sles TEAM=#{@team}")
    end
  end
end

