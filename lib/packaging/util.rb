# Utility methods used by the various rake tasks

module Pkg::Util
  require 'erb'
  require 'packaging/util/tool'
  require 'packaging/util/tools'
  require 'packaging/util/file'
  require 'packaging/util/version'
  require 'packaging/util/serialization'

  def self.symbolize_hash(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
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
