module Pkg
  ##
  #   This class is meant to encapsulate all of the data we know about a build invoked with
  #   `rake package:<build>` or `rake pl:<build>`. It can read in this data via a yaml file,
  #   have it set via accessors, and serialize it back to yaml for easy transport.
  #
  class Config
    require 'packaging/config/params.rb'
    require 'yaml'

    class << self

      #   Every element in Pkg::Params::BUILD_PARAMS is a configurable setting
      #   for the build. We use Pkg::Params::BUILD_PARAMS as the source of
      #   truth for defining the the class instance variables and their
      #   accessors of the Pkg::Config class
      Pkg::Params::BUILD_PARAMS.each do |v|
        attr_accessor v
      end

      #   Return the binding of class context. Used for erb templates.
      #
      def get_binding
        return binding
      end

      ##
      #   Take a hash of Config parameters, and iterate over them, setting the
      #   value for each Config param to the corresponding hash key,value.
      #
      def config_from_hash(data = {})
        data.each do |param, value|
          if Pkg::Params::BUILD_PARAMS.include?(param.to_sym)
            self.instance_variable_set("@#{param}", value)
          else
            warn "Warning - No build data parameter found for '#{param}'. Perhaps you have an erroneous entry in your yaml file?"
          end
        end
      end

      ##
      # Load a yaml file and use its contents to set the values for Pkg::Config
      # class instance variables
      #
      def config_from_yaml(file)
        build_data = Pkg::Util.load_yaml(file)
        config_from_hash(build_data)
      end

      ##
      # By default return a hash of the names, values of current Pkg::Config
      # instance variables. With :format => :yaml, write a yaml file containing
      # the current names,values of Pkg::Config class instance variables
      #
      def config(args={:target => nil, :format => :hash})
        case args[:format]
          when :hash
            self.config_to_hash
          when :yaml
            self.config_to_yaml(args[:target])
        end
      end

      ##
      # Return a hash of all build parameters and their values, nil if unassigned.
      #
      def config_to_hash
        data = {}
        Pkg::Params::BUILD_PARAMS.each do |param|
          data.store(param, self.instance_variable_get("@#{param}"))
        end
        data
      end

      ##
      # Write all build parameters to a yaml file, either one specified or in a
      # temporary location. Print the path to the file and return it as a
      # string. Accept an argument for the write target file. If not specified,
      # the name of the params file is the current git commit sha or tag.
      #
      def config_to_yaml(target=nil)
        target ||= File.join(Pkg::Util.mktemp, "#{self.ref}.yaml")
        Pkg::Util.file_writable?(File.dirname(target), :required => true)
        File.open(target, 'w') do |f|
          f.puts self.config_to_hash.to_yaml
        end
        puts target
        target
      end

      ##
      # Print the names and values of all the params known to the build object
      #
      def print_config
        self.config_to_hash.each { |k,v| puts "#{k}: #{v}" }
      end

      def load_defaults
        # It is really quite unsafe to assume github.com/puppetlabs/packaging has been
        # cloned into $project_root/ext/packaging even if it has _always_ been the
        # default location. We really don't have much choice as of this moment but to
        # assume this directory, or assume the user has passed in the correct one via
        # ENV['PROJECT_ROOT']. It is critical we have the correct $project_root, because
        # we get all of the package versioning from the `git-describe` of $project. If we
        # assume $project/ext/packaging, it means packaging/lib/packaging.rb is
        # three subdirectories below $project_root, e.g.,
        # $project_root/ext/packaging/lib/packaging.rb.
        #
        @project_root ||= ENV['PROJECT_ROOT'] || File.expand_path(File.join(LIBDIR, "..","..",".."))

        default_project_data = File.join(@project_root, "ext", "project_data.yaml")
        default_build_defaults = File.join(@project_root, "ext", "build_defaults.yaml")

        [default_project_data, default_build_defaults].each do |config|
          if File.readable? config
            self.config_from_yaml(config)
          else
            puts "Skipping load of expected default config #{config}, cannot read file."
            #   Since the default configuration files are not readable, most
            #   likely not present, at this point we assume the project_root
            #   isn't what we hoped it would be, and unset it.
            @project_root = nil
          end
        end
        #   Probably the single most important piece of data about our project,
        #   @ref determines what will eventually be the versioning for every
        #   package we can create. However, unles we're in a project root, we
        #   can't determine it
        if @project_root
          @ref = Pkg::Util.git_sha_or_tag
        else
          puts "Skipping determination of version (ref) via git describe, not in a known project root."
        end

      end

      ##
      # Since we're dealing with rake, much of the parameter override support
      # is via environment variables passed on the command line to a rake task.
      # These override any existing values of Pkg::Config class instance
      # variables
      #
      def load_envvars
        Pkg::Params::ENV_VARS.each do |v|
          if var = ENV[v[:envvar].to_s]
            if v[:type] == :bool
              self.instance_variable_set("@#{v[:var]}", Pkg::Util.boolean_value(var))
            else
              self.instance_variable_set("@#{v[:var]}", var)
            end
          end
        end
      end

    end
  end
end
