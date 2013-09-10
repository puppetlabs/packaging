# Utility methods for handling files and directories

module Pkg::Util

  class << self
    def mktemp
      mktemp = find_tool('mktemp', :required => true)
      `#{mktemp} -d -t pkgXXXXXX`.strip
    end

    def empty_dir?(dir)
      File.exist?(dir) and File.directory?(dir) and Dir["#{dir}/**/*"].empty?
    end

    def file_exists?(file, args={:required => false})
      exists = File.exist? file
      if !file_exists and args[:required]
        fail "Required file #{file} could not be found"
      end
      exists
    end

    def file_writable?(file, args={:required => false})
      writable = File.writable? file
      if !writable and args[:required]
        fail "File #{file} is not writable"
      end
      writable
    end

    alias :get_temp :mktemp

  end
end
