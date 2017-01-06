# Utility methods for dealing with serialization of Config params

module Pkg::Util::Serialization
  class << self

    # Given the path to a yaml file, load the yaml file into an object and return the object.
    def load_yaml(file)
      require 'yaml'
      file = File.expand_path(file)
      begin
        input_data = YAML.load_file(file) || {}
      rescue => e
        fail "There was an error loading data from #{file}.\n#{e}"
      end
      input_data
    end
  end
end

