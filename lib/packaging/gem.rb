module Pkg::Gem
  class << self
    def ship(file)
      Pkg::Util::File.file_exists?("#{ENV['HOME']}/.gem/credentials", :required => true)
      Pkg::Util::Execution.ex("gem push #{file}")
      begin
        Pkg::Util::Tool.check_tool("stickler")
        Pkg::Util::Execution.ex("stickler push #{file} --server=#{Pkg::Config.internal_gem_host} 2>/dev/null")
        puts "#{file} pushed to stickler server at #{Pkg::Config.internal_gem_host}"
      rescue
        puts "##########################################\n#"
        puts "#  Stickler failed, ensure it's installed"
        puts "#  and you have access to #{Pkg::Config.internal_gem_host} \n#"
        puts "##########################################"
      end
      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        Pkg::Util::Net.rsync_to("#{file}*", Pkg::Config.gem_host, Pkg::Config.gem_path)
      end
    end
  end
end
