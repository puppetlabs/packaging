# Utility methods for handling network calls and interactions

module Pkg::Util::Net

  class << self

    # This simple method does an HTTP get of a URI and writes it to a file
    # in a slightly more platform agnostic way than curl/wget
    def fetch_uri(uri, target)
      require 'open-uri'
      if Pkg::Util::File.file_writable?(File.dirname(target))
        File.open(target, 'w') { |f| f.puts(open(uri).read) }
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
      ssh = Pkg::Util::Tool.check_tool('ssh')
      puts "Executing '#{command}' on #{target}"
      Kernel.system("#{ssh} -t #{target} '#{command.gsub("'", "'\\\\''")}'")
      Pkg::Util::Execution.success? or raise "Remote ssh command failed."
    end

    def rsync_to(source, target, dest, ignore_existing = true)
      rsync = Pkg::Util::Tool.check_tool('rsync')
      flags = "-rHlv -O --no-perms --no-owner --no-group"
      flags << " --ignore-existing" if ignore_existing
      Pkg::Util::Execution.ex("#{rsync} #{flags} #{source} #{target}:#{dest}")
    end

    def rsync_from(source, target, dest)
      rsync = Pkg::Util::Tool.check_tool('rsync')
      flags = "-rHlv -O --no-perms --no-owner --no-group"
      Pkg::Util::Execution.ex("#{rsync} #{flags} #{target}:#{source} #{dest}")
    end

    # This is fairly absurd. We're implementing curl by shelling out. What do I
    # wish we were doing? Using a sweet ruby wrapper around curl, such as Curb or
    # Curb-fu. However, because we're using clean build systems and trying to
    # make this portable with minimal system requirements, we can't very well
    # depend on libraries that aren't in the ruby standard libaries. We could
    # also do this using Net::HTTP but that set of libraries is a rabbit hole to
    # go down when what we're trying to accomplish is posting multi-part form
    # data that includes file uploads to jenkins. It gets hairy fairly quickly,
    # but, as they say, pull requests accepted.
    #
    # This method takes three arguments
    # 1) String - the URL to post to
    # 2) Array  - Ordered array of name=VALUE curl form parameters
    # 3) Hash - Options to be set
    def curl_form_data(uri, form_data = [], options = {})
      curl = Pkg::Util::Tool.check_tool("curl")
      #
      # Begin constructing the post string.
      # First, assemble the form_data arguments
      #
      post_string = "-i "
      form_data.each do |param|
        post_string << "#{param} "
      end

      # Add the uri
      post_string << "#{uri}"

      # If this is quiet, we're going to silence all output
      if options[:quiet]
        post_string << " >#{Pkg::Util::OS::DEVNULL} 2>&1"
      end
      begin
        Pkg::Util::Execution.ex("#{curl} #{post_string}")
      rescue RuntimeError
        return false
      end
    end

    # Use the provided URL string to print important information with
    # ASCII emphasis
    def print_url_info(url_string)
      puts "\n////////////////////////////////////////////////////////////////////////////////\n\n
  Build submitted. To view your build progress, go to\n#{url_string}\n\n
////////////////////////////////////////////////////////////////////////////////\n\n"
    end
  end
end
