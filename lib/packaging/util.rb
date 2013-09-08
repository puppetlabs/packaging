# Utility methods used by the various rake tasks

module Pkg::Util
  require 'packaging/util/file'
  require 'packaging/util/tool'
  require 'packaging/util/version'
  require 'packaging/util/serialization'

  class << self
    def symbolize_hash(hash)
      hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    end

  end
end
