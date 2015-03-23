# A collection of utility methods that don't belong in any of our other top level Pkg::Util modules
# and probably won't anytime soon.

module Pkg::Util::Misc
  class << self
    # This method takes a string and a list of tokens and variables and it replaces
    # the listed tokens with the matched variable if it exists.
    def search_and_replace(search_string, replacements)
      replacements.each do |variable, token|
        begin
          if (replacement = Pkg::Config.send(variable))
            search_string.gsub!(token, replacement)
          end
        rescue NoMethodError
          warn "Pkg::Config doesn't have '#{variable}' defined"
        end
      end

      search_string
    end
  end
end
