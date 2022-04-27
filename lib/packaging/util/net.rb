# Utility methods for handling network calls and interactions

module Pkg::Util::Net
  class << self
    # This simple method does an HTTP get of a URI and writes it to a file
    # in a slightly more platform agnostic way than curl/wget
    def fetch_uri(uri, target)
      require 'open-uri'
      if Pkg::Util::File.file_writable?(File.dirname(target))
        File.open(target, 'w') { |f| f.puts(URI.open(uri).read) }
      end
    end

    # Get the hostname of the current host
    def hostname
      require 'socket'
      Socket.gethostname
    end

    # Check that the current host matches the one we think it should
    def check_host(host, options = { required: true })
      return true if hostname == host

      fail "Error: #{hostname} does not match #{host}" if options[:required]
      return nil
    end

    # @param hosts - An array of hosts to try ssh-ing into
    #  If the host needs a special username it should be passed
    #  in as user@host
    # @return an array of hosts where ssh access failed. Empty array if
    #  successful
    def check_host_ssh(hosts)
      errs = []
      Array(hosts).flatten.each do |host|
        begin
          remote_execute(host, 'exit', { extra_options: '-oBatchMode=yes' })
        rescue StandardError
          errs << host
        end
      end
      return errs
    end

    # @param hosts - An array of hosts to check for gpg keys
    #  If the host needs a special username it should be passed
    #  in as user@host
    # @param gpg - The gpg secret key to look for
    # @return an array of hosts where ssh access failed. Empty array if
    #  successful
    def check_host_gpg(hosts, gpg)
      errs = []
      Array(hosts).flatten.each do |host|
        begin
          remote_execute(host, "gpg --list-secret-keys #{gpg} > /dev/null 2&>1",
                         { extra_options: '-oBatchMode=yes' })
        rescue StandardError
          errs << host
        end
      end
      return errs
    end

    def remote_execute(target_host, command, user_options = {})
      option_defaults = {
        capture_output: false,
        extra_options: '',
        fail_fast: true,
        trace: false
      }
      options = option_defaults.merge(user_options)

      ssh = Pkg::Util::Tool.check_tool('ssh')

      # we pass some pretty complicated commands in via ssh. We need this to fail
      # if any part of the remote ssh command fails.
      shell_flags = ''
      shell_flags += 'set -e;' if options[:fail_fast]
      shell_flags += 'set -x;' if options[:trace]
      shell_commands = "#{shell_flags}#{command}"

      remote_command = "#{ssh} #{options[:extra_options]} -t #{target_host} " +
                       "'#{shell_commands.gsub("'", "'\\\\''")}'"

      # This is NOT a good way to support this functionality.
      if ENV['DRYRUN']
        puts "[DRY-RUN] Executing '#{command}' on #{target}"
        puts "[DRY-RUN] #{cmd}"
        return ''
      end

      # We're forced to make different calls depending on the capture_output option
      # because something about our #capture3 method screws up gpg. This should
      # be untangled.
      if options[:capture_output]
        stdout, stderr, exitstatus = Pkg::Util::Execution.capture3(remote_command)
        Pkg::Util::Execution.success?(exitstatus) or
          raise "Remote ssh command (\"#{remote_command}\") failed."
        return stdout, stderr
      end

      # Pkg::Util::Execution.capture3 reports its command but Kernel.system does not
      # Let's print it out for some amount of consistency.
      puts "Remote Execute: '#{remote_command}'"
      Kernel.system(remote_command)
      Pkg::Util::Execution.success? or
        raise "Remote ssh command (\"#{remote_command}\") failed."
    end

    ###
    ### Deprecated method implemented as a shim to the new `remote_execute` method
    ###
    def remote_ssh_cmd(target, command, capture_output = false, extra_options = '', fail_fast = true, trace = false) # rubocop:disable Metrics/ParameterLists
      puts "Warn: \"remote_ssh_cmd\" call in packaging is deprecated. Use \"remote_execute\" instead."
      remote_execute(target, command, {
                       capture_output: capture_output,
                       extra_options: extra_options,
                       fail_fast: fail_fast,
                       trace: trace
})
    end

    # Construct a valid rsync command
    # @return [String] a rsync command that can be used in shell or ssh methods
    # @param [String, Pathname] origin_path the path to sync from; if opts[:target_path]
    #   is not passed, then the parent directory of `origin_path` will be used to
    #   construct a target path to sync to.
    # @param [Hash] opts additional options that can be used to construct
    #   the rsync command.
    # @option opts [String] :bin ('rsync') the path to rsync
    #   (can be relative or fully qualified).
    # @option opts [String] :origin_host the remote host to sync data from; cannot
    #   be specified alongside :target_host
    # @option opts [String] :target_host the remote host to sync data to; cannot
    #   be specified alongside :origin_host.
    # @option opts [String] :extra_flags (["--ignore-existing"]) extra flags to
    #   use when constructing an rsync command
    # @option opts [String] :dryrun (false) tell rsync to perform a trial run
    #   with no changes made.
    # @raise [ArgumentError] if opts[:origin_host] and opts[:target_host] names
    #   are both defined.
    # @raise [ArgumentError] if :origin_path exists without opts[:target_path],
    #   opts[:origin_host], remote target is defined.
    def rsync_cmd(origin_path, opts = {})
      options = {
        bin: 'rsync',
        origin_host: nil,
        target_path: nil,
        target_host: nil,
        extra_flags: nil,
        dryrun: false
}.merge(opts)
      origin = Pathname.new(origin_path)
      target = options[:target_path] || origin.parent

      raise(ArgumentError, "Cannot sync between two remote hosts") if
        options[:origin_host] && options[:target_host]

      raise(ArgumentError, "Cannot sync path '#{origin}' because both origin_host and target_host are nil. Perhaps you need to set TEAM=release ?") unless
        options[:origin_host] || options[:target_host]

      cmd = %W[
        #{options[:bin]}
        --recursive
        --hard-links
        --links
        --verbose
        --omit-dir-times
        --no-perms
        --no-owner
        --no-group
      ] + [*options[:extra_flags]]

      cmd << '--dry-run' if options[:dryrun]
      cmd << Pkg::Util.pseudo_uri(path: origin, host: options[:origin_host])
      cmd << Pkg::Util.pseudo_uri(path: target, host: options[:target_host])

      cmd.uniq.compact.join("\s")
    end

    # A generic rsync execution method that wraps rsync_cmd in a
    # call to Pkg::Util::Execution#capture3()
    def rsync_exec(source, opts = {})
      options = {
        bin: Pkg::Util::Tool.check_tool('rsync'),
        origin_host: nil,
        target_path: nil,
        target_host: nil,
        extra_flags: nil,
        dryrun: ENV['DRYRUN']
}.merge(opts.delete_if { |_, value| value.nil? })

      stdout, = Pkg::Util::Execution.capture3(rsync_cmd(source, options), true)
      stdout
    end

    # A wrapper method to maintain the existing interface for executing
    # outbound rsync commands with minimal changes to existing code.
    def rsync_to(source, target_host, dest, opts = { extra_flags: ["--ignore-existing"] })
      rsync_exec(
        source,
        target_host: target_host,
        target_path: dest,
        extra_flags: opts[:extra_flags],
        dryrun: opts[:dryrun],
        bin: opts[:bin],
      )
    end

    # A wrapper method to maintain the existing interface for executing
    # incoming rsync commands with minimal changes to existing code.
    def rsync_from(source, origin_host, dest, opts = {})
      rsync_exec(
        source,
        origin_host: origin_host,
        target_path: dest,
        extra_flags: opts[:extra_flags],
        dryrun: opts[:dryrun],
        bin: opts[:bin],
      )
    end

    def s3sync_to(source, target_bucket, target_directory = "", flags = [])
      s3cmd = Pkg::Util::Tool.check_tool('s3cmd')

      if Pkg::Util::File.file_exists?(File.join(ENV['HOME'], '.s3cfg'))
        stdout, = Pkg::Util::Execution.capture3("#{s3cmd} sync #{flags.join(' ')} '#{source}' s3://#{target_bucket}/#{target_directory}/")
        stdout
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
      post_string << "'#{uri}'"

      # If this is quiet, we're going to silence all output
      begin
        stdout, _, retval = Pkg::Util::Execution.capture3("#{curl} #{post_string}")
        if options[:quiet]
          stdout = ''
        end
        return stdout, retval
      rescue RuntimeError => e
        puts e
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
      stdout, = Pkg::Util::Net.curl_form_data(uri, data)
      stdout
    end

    # Use the provided URL string to print important information with
    # ASCII emphasis
    def print_url_info(url_string)
      puts "\n////////////////////////////////////////////////////////////////////////////////\n\n
  Build submitted. To view your build progress, go to\n#{url_string}\n\n
////////////////////////////////////////////////////////////////////////////////\n\n"
    end

    def remote_set_ownership(host, owner, group, files)
      remote_cmd = "for file in #{files.join(' ')}; do if [[ -d $file ]] || ! `lsattr $file | grep -q '\\-i\\-'`; then sudo chown #{owner}:#{group} $file; else echo \"$file is immutable\"; fi; done"
      Pkg::Util::Net.remote_execute(host, remote_cmd)
    end

    def remote_set_permissions(host, permissions, files)
      remote_cmd = "for file in #{files.join(' ')}; do if [[ -d $file ]] || ! `lsattr $file | grep -q '\\-i\\-'`; then sudo chmod #{permissions} $file; else echo \"$file is immutable\"; fi; done"
      Pkg::Util::Net.remote_execute(host, remote_cmd)
    end

    # Remotely set the immutable bit on a list of files
    def remote_set_immutable(host, files)
      Pkg::Util::Net.remote_execute(host, "sudo chattr +i #{files.join(' ')}")
    end

    # Create a symlink indicating the latest version of a package
    #
    # @param package_name [String] The name of the package you want to symlink
    #   to, e.g. 'puppet-agent', 'facter', etc.
    # @param dir [String] The directory you want to find the latest package and
    #   create the symlink in.
    # @param platform_ext [String] The type of files you want to consider, e.g.
    #   'dmg', 'msi', etc.
    # @param options [Hash] Additional optional params:
    #   @option :arch [String] Architecture you want to narrow your search by.
    #   @option :excludes [Array] Strings you want to exclude from your search,
    #     e.g. 'agent' if only searching for 'puppet'.
    def remote_create_latest_symlink(package_name, dir, platform_ext, options = {})
      ls_cmd = "ls -1 *.#{platform_ext} | grep -v latest | grep -v rc | grep -P '#{package_name}-\\d' "

      # store this in a separate var to avoid side affects
      full_package_name = String.new(package_name)

      if options[:arch]
        ls_cmd << "| grep #{options[:arch]}"
        full_package_name << "-#{options[:arch]}"
      end
      if options[:excludes]
        options[:excludes].each do |excl|
          ls_cmd << "| grep -v #{excl} "
        end
      end
      ls_cmd << '| sort --version-sort | tail -1'
      cmd = <<-CMD
        if [ ! -d '#{dir}' ] ; then
          echo "directory '#{dir}' does not exist, not creating latest package link"
          exit 0
        fi
        pushd '#{dir}'
        link_target=$(#{ls_cmd})
        if [ -z "$link_target" ] ; then
          echo "Unable to find a link target for '#{full_package_name}' in '#{dir}'; skipping link creation"
          exit 0
        fi
        echo "creating link to '$link_target'"
        ln -sf "$link_target" #{full_package_name}-latest.#{platform_ext}
      CMD

      _, err = Pkg::Util::Net.remote_execute(
        Pkg::Config.staging_server, cmd, { capture_output: true }
      )
      warn err
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
    def remote_unpack_git_bundle(host, treeish, tar_cmd = nil, tarball = nil)
      unless tar = tar_cmd
        tar = 'tar'
      end
      tarball ||= Pkg::Util::Git.bundle(treeish)
      tarball_name = File.basename(tarball).gsub('.tar.gz', '')
      Pkg::Util::Net.rsync_to(tarball, host, '/tmp')
      appendix = Pkg::Util.rand_string
      git_bundle_directory = File.join('/tmp', "#{Pkg::Config.project}-#{appendix}")
      command = <<~DOC
        #{tar} -zxvf /tmp/#{tarball_name}.tar.gz -C /tmp/ ;
        git clone --recursive /tmp/#{tarball_name} #{git_bundle_directory} ;
      DOC
      Pkg::Util::Net.remote_execute(host, command)
      return git_bundle_directory
    end

    def remote_bundle_install_command
      rvm_ruby_version = ENV['RVM_RUBY_VERSION'] || '2.5.9'
      export_packaging_location = "export PACKAGING_LOCATION='#{ENV['PACKAGING_LOCATION']}';" if ENV['PACKAGING_LOCATION'] && !ENV['PACKAGING_LOCATION'].empty?
      export_vanagon_location = "export VANAGON_LOCATION='#{ENV['VANAGON_LOCATION']}';" if ENV['VANAGON_LOCATION'] && !ENV['VANAGON_LOCATION'].empty?
      "source /usr/local/rvm/scripts/rvm; rvm use ruby-#{rvm_ruby_version}; #{export_packaging_location} #{export_vanagon_location} bundle install --path .bundle/gems ;"
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
