# Utilities for managing/querying date/time

module Pkg::Util::Date
  class << self
    def timestamp(separator = nil)
      if s = separator
        format = "%Y#{s}%m#{s}%d#{s}%H#{s}%M#{s}%S"
      else
        format = "%Y-%m-%d %H:%M:%S"
      end
      Time.now.strftime(format)
    end

    def today
      format = "%m/%d/%Y"
      Time.now.strftime(format)
    end
  end
end
