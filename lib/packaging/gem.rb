module Pkg::Gem
  class << self
    # This is preserved because I don't want to update the deprecated code path
    # yet; I'm not entirely sure I've fixed everything that might attempt
    # to call this method so this is now a wrapper for a wrapper.
    def ship(file)
      rsync_to_downloads(file)
      ship_to_rubygems(file)
    end

    # Use rsync to deploy a file and any associated detached signatures,
    # checksums, or other glob-able artifacts to an external download server.
    def rsync_to_downloads(file)
      Pkg::Util::Net.rsync_to("#{file}*", Pkg::Config.gem_host, Pkg::Config.gem_path, dryrun: ENV['DRYRUN'])
    end

    # Ship a Ruby gem file to rubygems.org. Requires the existence
    # of a ~/.gem/credentials file or else rubygems.org won't have
    # any idea who you are.
    def ship_to_rubygems(file)
      Pkg::Util::File.file_exists?("#{ENV['HOME']}/.gem/credentials", :required => true)
      Pkg::Util::Execution.capture3("gem push #{file}")
    rescue => e
      puts "###########################################"
      puts "#  Publishing to rubygems failed. Make sure your .gem/credentials"
      puts "#  file is set up and you are an owner of #{Pkg::Config.gem_name}"
      puts "###########################################"
      puts
      puts e
      raise e
    end
  end
end
