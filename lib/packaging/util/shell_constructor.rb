require 'pathname'

module Pkg
  module Util
    # ShellConstructor builds strings that can be used by shelling
    # out or feeding them into remote ssh executors.
    module ShellConstructor
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
      # @option opts [String] :dryrun (false) tell rsync to perform a trial run
      #   with no changes made.
      # @raise [ArgumentError] if opts[:origin_host] and opts[:target_host] names
      #   are both defined.
      # @raise [ArgumentError] if :origin_path exists without opts[:target_path],
      #   opts[:origin_host], remote target is defined.
      def rsync(origin_path, opts = {})
        options = {
          bin: 'rsync',
          origin_host: nil,
          target_path: nil,
          target_host: nil,
          dryrun: false }.merge(opts)
        origin = cleanpath(origin_path)
        target = cleanpath(options[:target_path]) || origin.parent

        raise(ArgumentError, "Cannot sync between two remote hosts") if
          options[:origin_host] && options[:target_host]

        raise(ArgumentError, "Cannot sync path '#{origin}' to itself") unless
          options[:origin_host] || options[:target_host]

        cmd = %W(
          #{options[:bin]}
          --recursive
          --links
          --hard-links
          --update
          --human-readable
          --itemize-changes
          --progress
          --verbose
          --perms
          --omit-dir-times
          --no-group
          --no-owner
          --delay-updates
        )

        cmd << '--dry-run' if options[:dryrun]
        cmd << pseudo_uri(path: origin, host: options[:origin_host])
        cmd << pseudo_uri(path: target, host: options[:target_host])

        cmd.join("\s")
      end
      module_function :rsync

      # Construct a valid chmod command
      # @return [String] a chmod command that can be used in shell or ssh methods
      # @param [String, Pathname] path the path to run chmod on
      # @param [Hash] opts additional options that can be used to construct
      #   a chmod command.
      # @option opts [String] :bin ('chmod') the path to chmod
      #   (can be relative or fully qualified).
      # @option opts [String] :permissions ('u=rwX,g=rwX,a=rX') the permissions to use
      #   when constructing a chmod command; can be octal or symbolic. Note that this
      #   is not sanity checked for accuracy or validity.
      # @option opts [Boolean] :recursive ('false') whether or not chmod should
      #   be invoked recursively.
      def chmod(path, opts = {})
        options = {
          bin: 'chmod',
          permissions: 'ug=rwX,o=rX',
          recursive: false
        }.merge(opts)

        cmd = %W(
          #{options[:bin]}
          #{options[:permissions]}
          #{path}
        )

        # Insert '-R' into the array after the command name
        # if this should be a recursive call.
        cmd.insert(1, '-R') if options[:recursive]

        cmd.join("\s")
      end
      module_function :chmod

      # Construct a valid sudo command
      # @return [String] a sudo command that can be used in shell or ssh methods
      # @param [String] cmd a command-line string to preface with `sudo`
      # @param [Hash] opts additional options that can be used to construct
      #   the sudo command
      # @option opts [String] :bin ('sudo') the path to sudo
      #   (can be relative or fully qualified)
      # @option opts [String] :flags ('-E') flags to use when constructing a
      #   sudo command; defaults to inheriting the current environment of the
      #   user that runs the sudo command.
      def sudo(cmd, opts = {})
        options = { bin: 'sudo', flags: '-E' }.merge(opts)
        "#{options[:bin]} #{options[:flags]} #{cmd}"
      end
      module_function :sudo

      # Construct a probably-correct (or correct-enough) URI for
      # tools like ssh or rsync. Currently lacking support for intuitive
      # joins, ports, protocols, fragments, or 75% of what Addressable::URI
      # or URI would provide out of the box. The "win" here is that
      # the returned String should "just work".
      # @private pseudo_uri
      # @return [String, nil] a string representing either a hostname:/path pair,
      #   a hostname without a path, or a path without a hostname. Returns nil
      #   if it is unable to construct a useful URI-like string.
      # @param [Hash] opts fragments used to build the pseudo URI
      # @option opts [String] :path URI-ish path component
      # @option opts [String] :host URI-ish host component
      def pseudo_uri(opts = {})
        options = { path: nil, host: nil }.merge(opts)

        # Prune empty values to determine what is returned
        options.delete_if { |_, v| v.to_s.empty? }
        return nil if options.empty?

        [options[:host], options[:path]].compact.join(':')
      end
      module_function :pseudo_uri

      # Use the Pathname class from Ruby's Stdlib to coerce a
      # path into something relatively clean and concise.
      # @return [Pathname, nil] the cleanest version of a passed path.
      #   Returns nil if it is unable to parse or clean the passed path.
      # @param [String] path a path that should be sanitized
      def cleanpath(path)
        return path.cleanpath if path.respond_to? :cleanpath
        ::Pathname.new(path).cleanpath
      rescue
        nil
      end
      module_function :cleanpath

      class << self
        private :pseudo_uri
        private :cleanpath
      end
    end
  end
end
