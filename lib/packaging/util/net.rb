# Utility methods for handling network calls and interactions

module Pkg::Util::Net

  class << self

    # This simple method does an HTTP get of a URI and writes it to a file
    # in a slightly more platform agnostic way than curl/wget
    def fetch_uri(uri, target)
      require 'open-uri'
      if Pkg::Util::File.file_writable?(File.dirname(target))
        File.open(target, 'w') { |f| f.puts( open(uri).read ) }
      end
    end

    # Get the hostname of the current host
    def hostname
      require 'socket'
      Socket.gethostname
    end

    # Check that the current host matches the one we think it should
    def check_host(host, args = { :required => true })
      if hostname == host
        return true
      else
        fail "#{hostname} does not match #{host}" if args[:required]
        return nil
      end
    end

    def remote_ssh_cmd(target, command)
      Pkg::Util::Tool.check_tool('ssh')
      puts "Executing '#{command}' on #{target}"
      Kernel.system("ssh -t #{target} '#{command.gsub("'", "'\\\\''")}'")
      Pkg::Util::Execution.success? or raise "Remote ssh command failed."
    end

    def rsync_to(source, target, dest)
      rsync = Pkg::Util::Tool.check_tool('rsync')
      flags = "-rHlv -O --no-perms --no-owner --no-group --ignore-existing"
      ex("#{rsync} #{flags} #{source} #{target}:#{dest}")
    end

    def rsync_from(source, target, dest)
      rsync = Pkg::Util::Tool.check_tool('rsync')
      flags = "-rHlv -O --no-perms --no-owner --no-group"
      ex("#{rsync} #{flags} #{target}:#{source} #{dest}")
    end
  end
end
