if @build_pe
  pl_packaging_url = "https://raw.github.com/puppetlabs/build-data/#{@team}"
else
  pl_packaging_url = "https://raw.github.com/puppetlabs/build-data/#{@name}"
end

namespace :pl do
  task :fetch do
    rm_rf "#{ENV['HOME']}/.packaging"
    mkdir_p "#{ENV['HOME']}/.packaging"
    begin
      sh "curl #{pl_packaging_url}/#{@builder_data_file} > #{ENV['HOME']}/.packaging/#{@builder_data_file}"
    rescue
      STDERR.puts "There was an error fetching the builder extras data."
      exit 1
    end
  end
end
