module Pkg::Gem
  @nexus_config = "#{ENV['HOME']}/.gem/nexus"

  class << self
    # This is preserved because I don't want to update the deprecated code path
    # yet; I'm not entirely sure I've fixed everything that might attempt
    # to call this method so this is now a wrapper for a wrapper.
    def ship(file)
      ship_to_stickler(file)
      ship_to_nexus(file)
      rsync_to_downloads(file)
      ship_to_rubygems(file)
    end

    def load_nexus_config
      if Pkg::Util::File.file_exists?(@nexus_config)
        config = YAML.load_file(@nexus_config)
      end
      config || {}
    end

    def write_nexus_config
      hash = load_nexus_config
      if hash["GEM_INTERNAL"].nil? || hash["GEM_INTERNAL"][:authorization].nil?
        puts "Please enter nexus username:"
        username = Pkg::Util.get_input
        puts "Please enter nexus password:"
        password = Pkg::Util.get_input(false)
        hash["GEM_INTERNAL"] = { :authorization => "Basic #{Pkg::Util.base64_encode("#{username}:#{password}")}" }
      end
      if hash["GEM_INTERNAL"][:url].nil? || hash["GEM_INTERNAL"][:url] != Pkg::Config.internal_nexus_host
        hash["GEM_INTERNAL"][:url] = Pkg::Config.internal_nexus_host
      end
      File.open(@nexus_config, "w") do |file|
        file.write(hash.to_yaml)
      end
    end

    # Ship a Ruby gem file to a Nexus server, because
    # you've lost the ability to feel joy anymore.
    def ship_to_nexus(file)
      write_nexus_config
      cmd = "gem nexus #{file} --repo GEM_INTERNAL"
      if ENV['DRYRUN']
        puts "[DRY-RUN] #{cmd}"
      else
        ret = Pkg::Util::Execution.ex(cmd, true)
        # The `gem nexus` command always returns `0` regardless of what the
        # command results in. In order to properly handle fail cases, this
        # checks for the success case and fails otherwise. The `ex` command
        # above will print any output, so the user should have enough info
        # to debug the failure, and potentially update this fail case if
        # needed.
        fail unless ret.include? "Created"
        puts "#{file} pushed to nexus server at #{Pkg::Config.internal_nexus_host}"
      end
    rescue => e
      puts "###########################################"
      puts "#  Nexus failed, ensure the nexus gem is installed,"
      puts "#  you have access to #{Pkg::Config.internal_nexus_host}"
      puts "#  and your settings in #{@nexus_config} are correct"
      puts "###########################################"
      puts
      puts e
    end

    # Ship a Ruby gem file to a Stickler server, because
    # you've lost the ability to feel joy anymore.
    def ship_to_stickler(file)
      Pkg::Util::Tool.check_tool("stickler")
      cmd = "stickler push #{file} --server=#{Pkg::Config.internal_stickler_host} 2>/dev/null"
      if ENV['DRYRUN']
        puts "[DRY-RUN] #{cmd}"
      else
        Pkg::Util::Execution.ex(cmd)
        puts "#{file} pushed to stickler server at #{Pkg::Config.internal_stickler_host}"
      end
    rescue => e
      puts "###########################################"
      puts "#  Stickler failed, ensure it's installed"
      puts "#  and you have access to #{Pkg::Config.internal_stickler_host}"
      puts "###########################################"
      puts
      puts e
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
      Pkg::Util::Execution.ex("gem push #{file}")
    end
  end
end
