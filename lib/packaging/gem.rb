require 'json'
module Pkg::Gem
  class << self
    def ship(file)
      rsync_to_downloads(file)
      ship_to_rubygems(file)
    end

    # Use rsync to deploy a file and any associated detached signatures,
    # checksums, or other glob-able artifacts to an external download server.
    def rsync_to_downloads(file)
      Pkg::Util.deprecate('Pkg::Gem.rsync_to_downloads', 'Pkg::Util::Ship.ship_pkgs')
      Pkg::Util::Ship.ship_pkgs(["#{file}*"], Pkg::Config.gem_host,
                                Pkg::Config.gem_path, platform_independent: true)
    end

    def shipped_to_rubygems?(gem_name, gem_version, gem_platform)
      rubygems_url = "https://rubygems.org/api/v1/versions/#{gem_name}.json"
      gem_data = JSON.parse(%x(curl --silent #{rubygems_url}))
      gem = gem_data.select do |data|
        data['number'] == gem_version && data['platform'] == gem_platform
      end
      return !gem.empty?
    rescue StandardError => e
      puts "Something went wrong searching for gem '#{gem_name}':"
      puts e
      puts "Perhaps you're shipping '#{gem_name}' for the first time?"
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
        puts "#{file} has already been shipped to rubygems, skipping."
        return
      end
      Pkg::Util::File.file_exists?("#{ENV['HOME']}/.gem/credentials", :required => true)
      gem_push_command = "gem push #{file}"
      gem_push_command << " --host #{options[:host]}" if options[:host]
      gem_push_command << " --key #{options[:key]}" if options[:key]
      Pkg::Util::Execution.capture3(gem_push_command, true)
    rescue StandardError => e
      puts "###########################################"
      puts "#  Publishing to rubygems failed. Make sure your .gem/credentials"
      puts "#  file is set up and you are an owner of #{Pkg::Config.gem_name}"
      puts "###########################################"
      puts
      puts e
      # There appears to be a race condition where the rubygems versions api will not
      # be updated in time between builders attempting to push a gem. We want to avoid
      # failing here due to gem already being pushed, so if we identify this error
      # we can just log it and move on. NOTE: the gem push documentation does not
      # appear to provide a distinct error code for this kind of error so we rely on
      # string matching the stdout/stderr from the Pkg::Uti::execution method.
      unless e.message.match(/Repushing of gem versions is not allowed/)
        raise e
      end
    end

    def ship_to_internal_mirror(file)
      internal_mirror_api_key_name = 'artifactory_api_key'
      ship_to_rubygems(file, {
                         host: Pkg::Config.internal_gem_host,
                         key: internal_mirror_api_key_name
                       })
    end
  end
end
