# Utility methods used by the various rake tasks

module Pkg::Util
  require 'erb'
  require 'benchmark'
  require 'packaging/util/date'
  require 'packaging/util/tool'
  require 'packaging/util/file'
  require 'packaging/util/version'
  require 'packaging/util/serialization'

  def self.symbolize_hash(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

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

end
