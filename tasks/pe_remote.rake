# PE remote tasks
# We keep these around for backwards compatibility and as a backup in case the
# jenkins infrastructure fails. We hide them to reduce task clutter
if @build.build_pe
  namespace :pe do
    namespace :remote do
      task :deb => 'pl:fetch' do
        ENV['PE_VER'] ||= @build.pe_version
        check_var('PE_VER', ENV['PE_VER'])
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pe:deb PE_BUILD=#{@build.build_pe} TEAM=#{@build.team} PE_VER=#{ENV['PE_VER']}")
      end

      task :deb_all => 'pl:fetch' do
        ENV['PE_VER'] ||= @build.pe_version
        check_var('PE_VER', ENV['PE_VER'])
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.deb_build_host, 'HEAD', "pe:deb_all PE_BUILD=#{@build.build_pe} COW='#{@build.cows}' TEAM=#{@build.team} PE_VER=#{ENV['PE_VER']}")
      end

      task :mock => 'pl:fetch' do
        ENV['PE_VER'] ||= @build.pe_version
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pe:mock PE_BUILD=#{@build.build_pe} TEAM=#{@build.team} PE_VER=#{ENV['PE_VER']}")
      end

      task :mock_all => 'pl:fetch' do
        ENV['PE_VER'] ||= @build.pe_version
        Rake::Task["pl:remote:build"].reenable
        Rake::Task["pl:remote:build"].invoke(@build.rpm_build_host, 'HEAD', "pe:mock_all PE_BUILD=#{@build.build_pe} MOCK='#{@build.final_mocks}' TEAM=#{@build.team} PE_VER=#{ENV['PE_VER']}")
      end

      task :all => ['clean', 'pl:fetch'] do
        ['pe:remote:deb_all', 'pe:remote:mock_all', 'pe:ship_rpms', 'pe:ship_debs'].each do |task|
          Rake::Task[task].execute
        end
      end
    end
  end
end

