# Utility methods used by the various rake tasks

module Pkg::Util
  require 'erb'
  require 'benchmark'
  require 'base64'
  require 'io/console'
  require 'packaging/util/os'
  require 'packaging/util/date'
  require 'packaging/util/tool'
  require 'packaging/util/file'
  require 'packaging/util/misc'
  require 'packaging/util/net'
  require 'packaging/util/version'
  require 'packaging/util/serialization'
  require 'packaging/util/rake_utils'
  require 'packaging/util/jira'
  require 'packaging/util/execution'
  require 'packaging/util/git'
  require 'packaging/util/jenkins'
  require 'packaging/util/gpg'

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
end
