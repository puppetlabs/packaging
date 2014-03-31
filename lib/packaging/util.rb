# Utility methods used by the various rake tasks

module Pkg::Util
  require 'erb'
  require 'benchmark'
  require 'packaging/util/date'
  require 'packaging/util/tool'
  require 'packaging/util/file'
  require 'packaging/util/net'
  require 'packaging/util/version'
  require 'packaging/util/serialization'
  require 'packaging/util/rake_utils'

  def self.boolean_value(var)
    return TRUE if (var == TRUE || ( var.is_a?(String) && ( var.downcase == 'true' || var.downcase =~ /^y$|^yes$/ )))
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

end
