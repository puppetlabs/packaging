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

    def rsync_to(source, target, dest, extra_flags = ["--ignore-existing"])
      rsync = Pkg::Util::Tool.check_tool('rsync')
      flags = "-rHlv -O --no-perms --no-owner --no-group"
      unless extra_flags.empty?
        flags << " " << extra_flags.join(" ")
      end
      Pkg::Util::Execution.ex("#{rsync} #{flags} #{source} #{target}:#{dest}", true)
    end

    def rsync_from(source, target, dest, extra_flags = [])
      rsync = Pkg::Util::Tool.check_tool('rsync')
      flags = "-rHlv -O --no-perms --no-owner --no-group"
      unless extra_flags.empty?
        flags << " " << extra_flags.join(" ")
      end
      Pkg::Util::Execution.ex("#{rsync} #{flags} #{target}:#{source} #{dest}", true)
    end

    def s3sync_to(source, target_bucket, target_directory = "", flags = [])
      s3cmd = Pkg::Util::Tool.check_tool('s3cmd')

      if Pkg::Util::File.file_exists?(File.join(ENV['HOME'], '.s3cfg'))
        Pkg::Util::Execution.ex("#{s3cmd} sync #{flags.join(' ')} '#{source}' s3://#{target_bucket}/#{target_directory}/")
      else
        fail "#{File.join(ENV['HOME'], '.s3cfg')} does not exist. It is required to ship files using s3cmd."
      end
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

    def uri_status_code(uri)
      data = [
        '--request GET',
        '--silent',
        '--location',
        '--write-out "%{http_code}"',
        '--output /dev/null'
      ]
      Pkg::Util::Net.curl_form_data(uri, data)
    end

    # Use the provided URL string to print important information with
    # ASCII emphasis
    def print_url_info(url_string)
      puts "\n////////////////////////////////////////////////////////////////////////////////\n\n
  Build submitted. To view your build progress, go to\n#{url_string}\n\n
////////////////////////////////////////////////////////////////////////////////\n\n"
    end

    def remote_set_ownership(host, owner, group, files)
      remote_cmd = "for file in #{files.join(" ")}; do lsattr $file | grep -q '\\-i\\-'; if [ $? -eq 1 ]; then sudo chown #{owner}:#{group} $file; else echo \"$file is immutable\"; fi; done"
      Pkg::Util::Net.remote_ssh_cmd(host, remote_cmd)
    end

    def remote_set_permissions(host, permissions, files)
      remote_cmd = "for file in #{files.join(" ")}; do lsattr $file | grep -q '\\-i\\-'; if [ $? -eq 1 ]; then sudo chmod #{permissions} $file; else echo \"$file is immutable\"; fi; done"
      Pkg::Util::Net.remote_ssh_cmd(host, remote_cmd)
    end

    # Remotely set the immutable bit on a list of files
    def remote_set_immutable(host, files)
      Pkg::Util::Net.remote_ssh_cmd(host, "sudo chattr +i #{files.join(" ")}")
    end

    def escape_html(uri)
      require 'cgi'
      CGI.escapeHTML(uri)
    end

    # Add a parameter to a given uri. If we were sane we'd use
    # encode_www_form(params) of URI, but because we're not, because that will http
    # encode it, which isn't what we want since we're require the encoding provided
    # by escapeHTML of CGI, since this is being transfered in the xml of a jenkins
    # job via curl and DEAR JEEBUS WHAT HAVE WE DONE.
    def add_param_to_uri(uri, param)
      require 'uri'
      uri = URI.parse(uri)
      uri.query = [uri.query, param].compact.join('&')
      uri.to_s
    end

    # We take a tar argument for cases where `tar` isn't best, e.g. Solaris.  We
    # also take an optional argument of the tarball containing the git bundle to
    # use.
    def remote_bootstrap(host, treeish, tar_cmd = nil, tarball = nil)
      unless tar = tar_cmd
        tar = 'tar'
      end
      tarball ||= Pkg::Util::Git.git_bundle(treeish)
      tarball_name = File.basename(tarball).gsub('.tar.gz', '')
      Pkg::Util::Net.rsync_to(tarball, host, '/tmp')
      appendix = Pkg::Util.rand_string
      Pkg::Util::Net.remote_ssh_cmd(host, "#{tar} -zxvf /tmp/#{tarball_name}.tar.gz -C /tmp/ ; git clone --recursive /tmp/#{tarball_name} /tmp/#{Pkg::Config.project}-#{appendix} ; cd /tmp/#{Pkg::Config.project}-#{appendix} ; rake package:bootstrap")
      "/tmp/#{Pkg::Config.project}-#{appendix}"
    end

    # Given a BuildInstance object and a host, send its params to the host. Return
    # the remote path to the params.
    def remote_buildparams(host, build)
      params_file = build.config_to_yaml
      params_file_name = File.basename(params_file)
      params_dir = Pkg::Util.rand_string
      Pkg::Util::Net.rsync_to(params_file, host, "/tmp/#{params_dir}/")
      "/tmp/#{params_dir}/#{params_file_name}"
    end
  end
end
