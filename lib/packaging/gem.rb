module Pkg::Gem
  class << self
    # This is preserved because I don't want to update the deprecated code path
    # yet; I'm not entirely sure I've fixed everything that might attempt
    # to call this method so this is now a wrapper for a wrapper.
    def ship(file)
      ship_stickler(file)
      rsync_to_downloads(file)
      ship_to_rubygems(file)
    end

    # Ship a Ruby gem file to a Stickler server, because
    # you've lost the ability to feel joy anymore.
    def ship_to_stickler(file)
      Pkg::Util::Tool.check_tool("stickler")
      cmd = "stickler push #{file} --server=#{Pkg::Config.internal_gem_host} 2>/dev/null"
      if ENV['DRYRUN']
        puts "[DRY-RUN] #{cmd}"
      else
        Pkg::Util::Execution.ex(cmd)
        puts "#{file} pushed to stickler server at #{Pkg::Config.internal_gem_host}"
      end
    rescue
      puts "###########################################"
      puts "#  Stickler failed, ensure it's installed"
      puts "#  and you have access to #{Pkg::Config.internal_gem_host}"
      puts "###########################################"
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
