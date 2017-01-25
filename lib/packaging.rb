module Pkg

  LIBDIR = File.expand_path(File.dirname(__FILE__))

  $:.unshift(LIBDIR) unless
    $:.include?(File.dirname(__FILE__)) || $:.include?(LIBDIR)

  require 'packaging/util'
  require 'packaging/config'
  require 'packaging/config/build_params'
  require 'packaging/tar'
  require 'packaging/deb'
  require 'packaging/rpm'
  require 'packaging/osx'
  require 'packaging/ips'
  require 'packaging/nuget'
  require 'packaging/gem'
  require 'packaging/msi'
  require 'packaging/repo'

  # Load configuration defaults
  Pkg::Config.load_defaults
  Pkg::Config.load_default_configs
  Pkg::Config.load_versioning
  Pkg::Config.load_overrides
  Pkg::Config.load_envvars
  Pkg::Config.issue_reassignments
  Pkg::Config.issue_deprecations
end
