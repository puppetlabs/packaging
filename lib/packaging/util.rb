# Utility methods used by the various rake tasks

module Pkg::Util
  require 'packaging/util/file'
  require 'packaging/util/tool'
  require 'packaging/util/version'
  require 'packaging/util/serialization'

  def self.symbolize_hash(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

  def in_dir(dir, &blk)
    Dir.chdir dir do
      blk.call
    end
  end

end
