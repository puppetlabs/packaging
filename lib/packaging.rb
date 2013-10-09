module Pkg

  LIBDIR = File.expand_path(File.dirname(__FILE__))

  $:.unshift(LIBDIR) unless
    $:.include?(File.dirname(__FILE__)) || $:.include?(LIBDIR)

  require 'packaging/util'
  require 'packaging/config'
  require 'packaging/tar'

  # Load configuration defaults
  Pkg::Config.load_defaults
  Pkg::Config.load_envvars

end

