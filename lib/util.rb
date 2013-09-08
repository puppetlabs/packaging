# Utility methods used by the various rake tasks

module Pkg
  module Util

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

      def mktemp
        mktemp = find_tool('mktemp', :required => true)
        `#{mktemp} -d -t pkgXXXXXX`.strip
      end

      def empty_dir?(dir)
        File.exist?(dir) and File.directory?(dir) and Dir["#{dir}/**/*"].empty?
      end

      def symbolize_hash(hash)
        hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      end

      alias :has_tool :find_tool
      alias :get_temp :mktemp

    end
  end
end
