# Utility methods for handling system binaries

module Pkg::Util

  class << self
    def check_tool(tool)
      return true if has_tool(tool)
      fail "#{tool} tool not found...exiting"
    end

    def find_tool(tool, args={:required => false})
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |root|
        location = File.join(root, tool)
        return location if FileTest.executable? location
      end
      fail "#{tool} tool not found...exiting" if args[:required]
      return nil
    end

    alias :has_tool :find_tool

  end
end
