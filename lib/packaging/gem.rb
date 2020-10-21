require 'json'
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

    def shipped_to_rubygems?(gem_name, gem_version, gem_platform)
      rubygems_url = "https://rubygems.org/api/v1/versions/#{gem_name}.json"
      gem_data = JSON.parse(%x[curl --silent #{rubygems_url}])
      gem = gem_data.select { |data| data['number'] == gem_version && data['platform'] == gem_platform }
      return !gem.empty?
    rescue => e
      puts "Uh oh, something went wrong searching for gem '#{gem_name}':"
      puts e
      puts "Perhaps you're shipping gem '#{gem_name}' for the first time? Congrats!"
      return false
    end

    # Ship a Ruby gem file to rubygems.org. Requires the existence
    # of a ~/.gem/credentials file or else rubygems.org won't have
    # any idea who you are.
    def ship_to_rubygems(file, options = {})
      # rubygems uses 'ruby' as the platform when it's not a platform-specific
      # gem
      platform = file.match(/\w+-(?:\d+(?:\.)?)+-(.*)\.gem$/)
      unless platform.nil?
        gem_platform = platform[1]
      end
      gem_platform ||= 'ruby'

      if shipped_to_rubygems?(Pkg::Config.gem_name, Pkg::Config.gemversion, gem_platform)
        puts "#{file} has already been shipped to rubygems, skipping . . ."
        return
      end
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
      internal_mirror_api_key_name = 'artifactory_api_key'
      ship_to_rubygems(file, { :host => Pkg::Config.internal_gem_host, :key => internal_mirror_api_key_name })
    end
  end
end
