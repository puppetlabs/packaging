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
  end
end
