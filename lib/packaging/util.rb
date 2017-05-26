# Utility methods used by the various rake tasks
module Pkg::Util
  require 'erb'
  require 'benchmark'
  require 'base64'
  require 'io/console'
  require 'packaging/util/date'
  require 'packaging/util/execution'
  require 'packaging/util/file'
  require 'packaging/util/git'
  require 'packaging/util/gpg'
  require 'packaging/util/jenkins'
  require 'packaging/util/misc'
  require 'packaging/util/net'
  require 'packaging/util/os'
  require 'packaging/util/platform'
  require 'packaging/util/serialization'
  require 'packaging/util/tool'
  require 'packaging/util/rake_utils'
  require 'packaging/util/version'
  require 'packaging/util/git_tags'

  def self.boolean_value(var)
    return TRUE if var == TRUE || ( var.is_a?(String) && ( var.downcase == 'true' || var.downcase =~ /^y$|^yes$/))
    FALSE
  end

  def self.in_project_root(&blk)
    result = nil
    fail "Cannot execute in project root if Pkg::Config.project_root is not set" unless Pkg::Config.project_root

    Dir.chdir Pkg::Config.project_root do
      result = blk.call
    end
    result
  end

  # Utility to get the contents of an Environment variable
  #
  # @param var [String] The name of the environment variable to return
  # @return [String, Boolean, Hash, Array, nil] The contents of ENV[var]
  def self.get_var(var)
    self.check_var(var, ENV[var])
    ENV[var]
  end

  # Utility to check if a variable is set
  #
  # @param varname [String] the name of the variable to be checked
  # @param var [String, Boolean, Hash, Array, nil] the contents of the variable to be checked
  # @return [String, Boolean, Hash, Array, nil] the contents of var
  # @raise [RuntimeError] raises an exception if the variable is not set and is required
  def self.check_var(varname, var)
    fail "Requires #{varname} be set!" if var.nil?
    var
  end

  def self.require_library_or_fail(library, library_name = nil)
    library_name ||= library
    begin
      require library
    rescue LoadError
      fail "Could not load #{library_name}. #{library_name} is required by the packaging repo for this task"
    end
  end

  def self.base64_encode(string)
    Base64.encode64(string).strip
  end

  # Utility to retrieve command line input
  # @param noecho [Boolean, nil] if we are retrieving command line input with or without privacy. This is mainly
  #   for sensitive information like passwords.
  def self.get_input(echo = true)
    fail "Cannot get input on a noninteractive terminal" unless $stdin.tty?

    system 'stty -echo' unless echo
    $stdin.gets.chomp!
  ensure
    system 'stty echo'
  end

  def self.rand_string
    rand.to_s.split('.')[1]
  end

  def self.ask_yes_or_no(force = false)
    unless force
      return Pkg::Util.boolean_value(Pkg::Config.answer_override) unless Pkg::Config.answer_override.nil?
    end

    answer = Pkg::Util.get_input
    return true if answer =~ /^y$|^yes$/
    return false if answer =~ /^n$|^no$/
    puts "Nope, try something like yes or no or y or n, etc:"
    Pkg::Util.ask_yes_or_no
  end

  def self.confirm_ship(files)
    $stdout.puts "Artifacts will be shipped to the following hosts:"
    Pkg::Util.filter_configs('host').each { |key, value| puts "#{key}: #{value}" }
    $stdout.puts "Does this look right?? [y,n]"
    Pkg::Util.ask_yes_or_no(true)
    $stdout.puts "The following files have been built and are ready to ship:"
    files.each { |file| puts "\t#{file}\n" unless File.directory?(file) }
    $stdout.puts "Ship these files?? [y,n]"
    Pkg::Util.ask_yes_or_no(true)
  end

  def self.filter_configs(filter = nil)
    return Pkg::Config.instance_values.select { |key, _| key.match(/#{filter}/) } if filter
    Pkg::Config.instance_values
  end


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
  def self.pseudo_uri(opts = {})
    options = { path: nil, host: nil }.merge(opts)

    # Prune empty values to determine what is returned
    options.delete_if { |_, v| v.to_s.empty? }
    return nil if options.empty?

    [options[:host], options[:path]].compact.join(':')
  end

  def self.deprecate(old_cmd, new_cmd = nil)
    msg = "!! #{old_cmd} is deprecated."
    if new_cmd
      msg << " Please use #{new_cmd} instead."
    end
    $stdout.puts("\n#{msg}\n")
  end
end
