module Pkg
  ##
  # This module is meant to encapsulate all of the data we know about a build invoked with
  # `rake package:<build>` or `rake pl:<build>`. It can read in this data via a yaml file,
  # have it set via accessors, and serialize it back to yaml for easy transport.
  #
  module Config
    require 'packaging/config/params.rb'
    require 'yaml'

    class << self

      Pkg::Config::PARAMS.each do |v|
        attr_accessor v
      end

      # Probably the single most important piece of data about our project,
      # @ref determines what will eventually be the versioning for every package we can
      # create. We _always_ set @ref for the Pkg::Config module. Always.
      @ref = Pkg::Util.git_sha_or_tag

      ##
      # Take a hash of Config parameters, and iterate over them, setting the
      # value for each Config param to the corresponding hash key,value.
      #
      def params_from_hash(data = {})
        data.each do |param, value|
          if Pkg::Config::PARAMS.include?(param.to_sym)
            self.instance_variable_set("@#{param}", value)
          else
            warn "Warning - No build data parameter found for '#{param}'. Perhaps you have an erroneous entry in your yaml file?"
          end
        end
      end

      def params_from_yaml(file)
        build_data = Pkg::Util.load_yaml(file)
        params_from_hash(build_data)
      end

      ##
      # Return a hash of all build parameters and their values, nil if unassigned.
      #
      def params_hash
        data = {}
        Pkg::Config::PARAMS.each do |param|
          data.store(param, self.instance_variable_get("@#{param}"))
        end
        data
      end

      ##
      # Write all build parameters to a yaml file in a temporary location. Print
      # the path to the file and return it as a string. Accept an argument for
      # the write target directory. The name of the params file is the current
      # git commit sha or tag.
      #
      def params_to_yaml(output_dir=nil)
        dir = output_dir.nil? ? Pkg::Util.mktemp : output_dir
        File.writable?(dir) or fail "#{dir} does not exist or is not writable, skipping build params write. Exiting.."
        params_file = File.join(dir, "#{self.ref}.yaml")
        File.open(params_file, 'w') do |f|
          f.puts self.params_hash.to_yaml
        end
        puts params_file
        params_file
      end

      ##
      # Print the names and values of all the params known to the build object
      #
      def print_params
        self.params.each { |k,v| puts "#{k}: #{v}" }
      end

    end
  end
end
