# Utility methods for handling files and directories

module Pkg::Util::File

  class << self
    def mktemp
      mktemp = Pkg::Util::Tool.find_tool('mktemp', :required => true)
      `#{mktemp} -d -t pkgXXXXXX`.strip
    end

    def empty_dir?(dir)
      File.exist?(dir) and File.directory?(dir) and Dir["#{dir}/**/*"].empty?
    end

    def file_exists?(file, args={:required => false})
      exists = File.exist? file
      if !exists and args[:required]
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

    def erb_string(erbfile, b = binding)
      template = File.read(erbfile)
      message  = ERB.new(template, nil, "-")
      message.result(b)
    end

    def erb_file(erbfile, outfile=nil, opts = { :remove_orig => false, :binding => binding })
      outfile ||= File.join(mktemp, File.basename(erbfile).sub(File.extname(erbfile),""))
      output = erb_string(erbfile, opts[:binding])
      File.open(outfile, 'w') { |f| f.write output }
      puts "Generated: #{outfile}"
      FileUtils.rm_rf erbfile if opts[:remove_orig]
      outfile
    end
  end
end

