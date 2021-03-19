# Utility methods for handling system os information

require 'rbconfig'

module Pkg::Util::OS
  module_function

  def windows?
    case RbConfig::CONFIG['host_os']
    when /mswin|mingw/i
      true
    else
      false
    end
  end

  DEVNULL = windows? ? 'NUL' : '/dev/null'
end
