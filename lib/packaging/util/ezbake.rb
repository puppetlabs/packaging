# Utility methods for handling ezbake

require 'fileutils'

module Pkg::Util::EZbake
  class << self
    def add_manifest(target_directory)
      ezbake_manifest = File.join('ext', 'ezbake.manifest')
      ezbake_yaml = File.join('ext', 'ezbake.manifest.yaml')

      if File.exist?(ezbake_manifest)
        FileUtils.cp(
          ezbake_manifest,
          File.join(target_directory, "#{Pkg::Config.ref}.ezbake.manifest")
        )
      end

      if File.exist?(ezbake_yaml)
        FileUtils.cp(
          ezbake_yaml,
          File.join(target_directory, "#{Pkg::Config.ref}.ezbake.manifest.yaml")
        )
      end
    end
  end
end
