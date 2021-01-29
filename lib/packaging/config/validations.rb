module Pkg
  class ConfigValidations

    class << self

      # As a validation, this one is kindof lame but is intended as a seed pattern for possibly
      # more robust ones.
      def not_empty?(value)
        value.to_s.empty? ? false : true
      end
    end
  end
end
