# Utility methods for dealing with serialization of Config params

module Pkg::Util::Serialization
  class << self
    # Given the path to a yaml file, load the yaml file into an object and return the object.
    def load_yaml(file_path)
      require 'yaml'
      YAML.load_file(File.expand_path(file_path))
    rescue => e
      fail "Error: Could not read yaml file: #{file_path}.\n#{e}"
    end
  end
end
