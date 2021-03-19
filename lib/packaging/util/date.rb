# Utilities for managing/querying date/time

module Pkg::Util::Date
  class << self
    def timestamp(separator = nil)
      format = if s = separator
                 "%Y#{s}%m#{s}%d#{s}%H#{s}%M#{s}%S"
               else
                 "%Y-%m-%d %H:%M:%S"
               end
      Time.now.strftime(format)
    end

    def today
      format = "%m/%d/%Y"
      Time.now.strftime(format)
    end
  end
end
