# Shipping methods for handling ezbake

require 'fileutils'

module Pkg::Ship::EZbake
  class << self
    def add_manifest(target_directory)
      manifest_name = 'ezbake.manifest'
      ezbake_manifest_source_path = File.join('ext', manifest_name)
      ezbake_manifest_target_path = nil
      if File.exist?(ezbake_manifest_source_path)
        ezbake_manifest_target_path = File.join(
          target_directory, "#{Pkg::Config.ref}.#{manifest_name}")
        FileUtils.cp(ezbake_manifest_source_path, ezbake_manifest_target_path)
      end

      yaml_name = 'ezbake.manifest.yaml'
      ezbake_yaml_source_path = File.join('ext', yaml_name)
      ezbake_yaml_target_path = nil
      if File.exist?(ezbake_yaml_source_path)
        ezbake_yaml_target_path = File.join(
          target_directory, "#{Pkg::Config.ref}.#{yaml_name}")
        FileUtils.cp(ezbake_yaml_source_path, ezbake_yaml_target_path)
      end

      return {
        manifest_path: ezbake_manifest_target_path,
        yaml_path: ezbake_yaml_target_path
      }
    end
  end
end
