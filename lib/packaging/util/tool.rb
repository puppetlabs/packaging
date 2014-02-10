# Utility methods for handling system binaries

module Pkg::Util::Tool

  #   Set up utility methods for handling system binaries
  #
  class << self
    def check_tool(tool)
      find_tool(tool, :required => true)
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

  #   Set up paths to system tools we use in the packaging repo
  #   no matter what distribution we're packaging for.

  GIT = Pkg::Util::Tool.find_tool('git', :required => :true)

end
