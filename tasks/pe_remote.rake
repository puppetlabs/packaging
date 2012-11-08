# For PE, the natural default tasks are the remote tasks, rather than
# the local ones, in reflection of which will be most ideal for PE devs.
# e.g., pe:local_deb is the task to build a deb on the local host,
# while pe:deb is the task for building on the remote builder host

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
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pe:local_mock TEAM=#{@team}")
    end

    desc "Execute remote rpm build with ALL mocks on builder and retrieve packages"
    task :mock_all => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pe:local_mock_final TEAM=#{@team}")
    end

    desc "Execute remote sles rpm build and retrieve package"
    task :sles => ['pl:fetch', 'pl:load_extras'] do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@sles_build_host, 'HEAD', "pe:local_sles TEAM=#{@team}")
    end
  end
end

