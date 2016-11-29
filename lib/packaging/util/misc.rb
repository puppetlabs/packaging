# A collection of utility methods that don't belong in any of our other top level Pkg::Util modules
# and probably won't anytime soon.

module Pkg::Util::Misc
  class << self
    # This method takes a string and a list of tokens and variables and it replaces
    # the listed tokens with the matched variable if it exists. All values will
    # be explicitly coerced to strings.
    def search_and_replace(search_string, replacements)
      raise ArgumentError "replacements must respond to #each_pair" unless
        replacements.respond_to? :each_pair

      replacements.each_pair do |token, value|
        unless value
          warn "replacement value for '#{token}' probably shouldn't be nil"
          next
        end

        search_string.gsub!(token.to_s, value.to_s)
      end

      search_string
    end

    # Loads and parses json from a file. Will treat the keys in the
    # json as methods to invoke on the component in question
    #
    # @param file [String] Path to the json file
    # @raise [RuntimeError] exceptions are raised if there is no file, if it refers to methods that don't exist, or if it does not contain a Hash
    def load_from_json(file)
      data = JSON.parse(File.read(file))
      unless data.is_a?(Hash)
        raise "Hash required. Got '#{data.class}' when parsing '#{file}'"
      end
      # We explicity return data here b/c the unless clause above will cause the
      # Function to return nil.
      #               -Sean P. M. 05/11/2016
      data
    end

    # @param gem the name of the gem to see if it is installed
    # @return boolean for whether or not the gem is installed
    def check_gem(gem)
      if %x(gem list -q #{gem}).chomp.empty?
        return false
      else
        return true
      end
    end

    # This loads your ~/.gem/credentials file and uses your api key
    # to query rubygems.org for which gems you own. There may be better ways
    # to query this but having to pull this information using curl is sort of
    # gross. It works though, so ¯\_(ツ)_/¯
    # @param gem_name the gem to check if you are an owner
    # @return boolean whether or not you own the gem
    def check_rubygems_ownership(gem_name)
      require 'yaml'
      credentials = YAML.load_file("#{ENV['HOME']}/.gem/credentials")
      gems = YAML.load(%x(curl -H 'Authorization:#{credentials[:rubygems_api_key]}' https://rubygems.org/api/v1/gems.yaml))
      gems.each do |gem|
        if gem['name'] == gem_name
          return true
        end
      end
      return false
    end
  end
end
