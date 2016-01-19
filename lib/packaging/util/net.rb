# Utility methods for handling network calls and interactions

module Pkg
  module Util
    module Net
      # This simple method does an HTTP get of a URI and writes it to a file
      # in a slightly more platform agnostic way than curl/wget
      def fetch_uri(uri, target)
        require 'open-uri'
        if Pkg::Util::File.file_writable?(File.dirname(target))
          File.open(target, 'w') { |f| f.puts(open(uri).read) }
        end
      end
      module_function :fetch_uri

      # Get the hostname of the current host
      def hostname
        require 'socket'
        Socket.gethostname
      end
      module_function :hostname

      # Check that the current host matches the one we think it should
      def check_host(host, args = { :required => true })
        if hostname == host
          return true
        else
          fail "#{hostname} does not match #{host}" if args[:required]
          return nil
        end
      end
      module_function :check_host

      def remote_ssh_cmd(target, command, capture_output = false)
        ssh = Pkg::Util::Tool.check_tool('ssh')
        cmd = "#{ssh} -t #{target} '#{command.gsub("'", "'\\\\''")}'"

        # This is NOT a good way to support this functionality.
        # It needs to be refactored into a set of methods that
        # other methods can use to safely and deterministically
        # support dry-run operations.
        # But I need to ship packages RIGHT NOW.
        # - Ryan McKern, 13/01/2016
        if ENV['DRYRUN']
          puts "[DRY-RUN] Executing '#{command}' on #{target}"
          puts "[DRY-RUN] #{cmd}"
          return
        end

        puts "Executing '#{command}' on #{target}"
        if capture_output
          require 'open3'
          stdout, stderr, exitstatus = Open3.capture3(cmd)
          Pkg::Util::Execution.success?(exitstatus) or raise "Remote ssh command failed."
          return stdout, stderr
        else
          Kernel.system(cmd)
          Pkg::Util::Execution.success? or raise "Remote ssh command failed."
        end
      end
      module_function :remote_ssh_cmd

      def rsync_to(source, target, dest, extra_flags = ["--ignore-existing"])
        rsync = Pkg::Util::Tool.check_tool('rsync')
        flags = "-rHlv -O --no-perms --no-owner --no-group"
        unless extra_flags.empty?
          flags << " " << extra_flags.join(" ")
        end
        Pkg::Util::Execution.ex("#{rsync} #{flags} #{source} #{target}:#{dest}", true)
      end
      module_function :rsync_to

      def rsync_from(source, target, dest, extra_flags = [])
        rsync = Pkg::Util::Tool.check_tool('rsync')
        flags = "-rHlv -O --no-perms --no-owner --no-group"
        unless extra_flags.empty?
          flags << " " << extra_flags.join(" ")
        end
        Pkg::Util::Execution.ex("#{rsync} #{flags} #{target}:#{source} #{dest}", true)
      end
      module_function :rsync_from

      def s3sync_to(source, target_bucket, target_directory = "", flags = [])
        s3cmd = Pkg::Util::Tool.check_tool('s3cmd')

        if Pkg::Util::File.file_exists?(File.join(ENV['HOME'], '.s3cfg'))
          Pkg::Util::Execution.ex("#{s3cmd} sync #{flags.join(' ')} '#{source}' s3://#{target_bucket}/#{target_directory}/")
        else
          fail "#{File.join(ENV['HOME'], '.s3cfg')} does not exist. It is required to ship files using s3cmd."
        end
      end
      module_function :s3sync_to

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
      module_function :curl_form_data

      # Use the provided URL string to print important information with
      # ASCII emphasis
      def print_url_info(url_string)
        str = "\n////////////////////////////////////////////////////////////////////////////////\n\n\n"
        str += "\s\sBuild submitted. To view your build progress, go to\n#{url_string}\n\n\n"
        str += "////////////////////////////////////////////////////////////////////////////////\n\n"
        puts str
      end
      module_function :print_url_info
    end
  end
end
