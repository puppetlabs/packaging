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

    def check_file(file, args={:required => false})
      file_exists = File.exist? file
      if !file_exists and args[:required]
        fail "Required file #{file} could not be found"
      end
      file_exists
    end

    alias :get_temp :mktemp

  end
end
