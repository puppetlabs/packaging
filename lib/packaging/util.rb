# Utility methods used by the various rake tasks

module Pkg::Util
  require 'erb'
  require 'benchmark'
  require 'packaging/util/os'
  require 'packaging/util/date'
  require 'packaging/util/tool'
  require 'packaging/util/file'
  require 'packaging/util/net'
  require 'packaging/util/version'
  require 'packaging/util/serialization'
  require 'packaging/util/rake_utils'
  require 'packaging/util/jira'
  require 'packaging/util/execution'

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

  def self.get_var(var)
    check_var(var, ENV[var])
    ENV[var]
  end

  def self.require_library_or_fail(library, library_name = nil)
    library_name ||= library
    begin
      require library
    rescue LoadError
      raise "Could not load #{library_name}. #{library_name} is required by the packaging repo for this task"
    end
  end

end
