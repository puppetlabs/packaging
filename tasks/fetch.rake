if @build_pe
  pl_packaging_url = "https://raw.github.com/puppetlabs/build-data/pe"
else
  pl_packaging_url = "https://raw.github.com/puppetlabs/build-data/#{@name}"
end

namespace :pl do
  task :fetch do
    rm_rf "#{ENV['HOME']}/.packaging"
    mkdir_p "#{ENV['HOME']}/.packaging"
    sh "curl #{pl_packaging_url}/#{@builder_data_file} > #{ENV['HOME']}/.packaging/#{@builder_data_file}"
    begin
      @build_data = YAML.load_file("#{ENV['HOME']}/.packaging/#{@builder_data_file}")
      @rpm_build_host = @build_data['rpm_build_host']
      @deb_build_host = @build_data['deb_build_host']
      @osx_build_host = @build_data['osx_build_host']
      @tarball_path   = @build_data['tarball_path']
      @dmg_path       = @build_data['dmg_path']
      @pe_version     = @build_data['pe_version']
    rescue
      STDERR.puts "There was an error loading the builder data from #{ENV['HOME']}/.packaging/#{@builder_data_file}"
      exit 1
    end
  end
end
