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
      Pkg::Util.deprecate('Pkg::Gem.rsync_to_downloads', 'Pkg::Util::Ship.ship_pkgs')
      Pkg::Util::Ship.ship_pkgs(["#{file}*"], Pkg::Config.gem_host, Pkg::Config.gem_path, platform_independent: true)
    end

    # Ship a Ruby gem file to rubygems.org. Requires the existence
    # of a ~/.gem/credentials file or else rubygems.org won't have
    # any idea who you are.
    def ship_to_rubygems(file, options = {})
      Pkg::Util::File.file_exists?("#{ENV['HOME']}/.gem/credentials", :required => true)
      gem_push_command = "gem push #{file}"
      gem_push_command << " --host #{options[:host]}" if options[:host]
      gem_push_command << " --key #{options[:key]}" if options[:key]
      Pkg::Util::Execution.capture3(gem_push_command)
    rescue => e
      puts "###########################################"
      puts "#  Publishing to rubygems failed. Make sure your .gem/credentials"
      puts "#  file is set up and you are an owner of #{Pkg::Config.gem_name}"
      puts "###########################################"
      puts
      puts e
      raise e
    end

    def ship_to_internal_mirror(file)
      internal_mirror_url = 'https://artifactory.delivery.puppetlabs.net/artifactory/api/gems/rubygems'
      internal_mirror_api_key_name = 'artifactory_api_key'
      ship_to_rubygems(file, { :host => internal_mirror_url, :key => internal_mirror_api_key_name })
    end
  end
end
