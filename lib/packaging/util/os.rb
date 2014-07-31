# Utility methods for handling system os information

require 'rbconfig'

module Pkg::Util::OS
  def windows?
    case RbConfig::CONFIG['host_os']
    when /mswin|mingw/i
      true
    else
      false
    end
  end
  module_function :windows?

  DEVNULL = windows? ? 'NUL' : '/dev/null'
end
