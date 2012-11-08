if @build_pe
  pl_packaging_url = "https://raw.github.com/puppetlabs/build-data/#{@team}"
else
  pl_packaging_url = "https://raw.github.com/puppetlabs/build-data/#{@name}"
end

# The pl:fetch task pulls down a file from the build-data repo that contains additional
# data specific to Puppet Labs release infrastructure intended to augment/override any
# defaults specified in the source project repo, e.g. in ext/build_defaults.yaml
#
# It uses curl to download the file, and places it in a hidden directory in the home
# directory, e.g. ~/.packaging/@builder_data_file
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
