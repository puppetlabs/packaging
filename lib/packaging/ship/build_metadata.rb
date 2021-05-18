# Utility methods for shipping miscellaneous build metadata

require 'fileutils'

module Pkg::Ship::BuildMetadata
  class << self
    def add_misc_json_files(target_directory)
      misc_json_files = Dir.glob('ext/build_metadata*.json')
      misc_json_files.each do |source_file|
        target_file = File.join(
          target_directory, "#{Pkg::Config.ref}.#{File.basename(source_file)}"
        )
        FileUtils.cp(source_file, target_file)
      end
    end
  end
end
