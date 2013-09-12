# Utility methods used by the various rake tasks

module Pkg::Util
  require 'packaging/util/tool'
  require 'packaging/util/tools'
  require 'packaging/util/file'
  require 'packaging/util/version'
  require 'packaging/util/serialization'

  def self.symbolize_hash(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

  def self.in_project_root(&blk)
    Dir.chdir Pkg::PROJECT_ROOT do
      blk.call
    end
  end

end
