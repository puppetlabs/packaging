module Pkg

  LIBDIR = File.expand_path(File.dirname(__FILE__))

  $:.unshift(LIBDIR) unless
    $:.include?(File.dirname(__FILE__)) || $:.include?(LIBDIR)

  require 'packaging/util'

  require 'packaging/archive'
  require 'packaging/artifactory'
  require 'packaging/config'
  require 'packaging/deb'
  require 'packaging/fetch'
  require 'packaging/gem'
  require 'packaging/metrics'
  require 'packaging/nuget'
  require 'packaging/paths'
  require 'packaging/platforms'
  require 'packaging/repo'
  require 'packaging/retrieve'
  require 'packaging/rpm'
  require 'packaging/sign'
  require 'packaging/ship'
  require 'packaging/tar'

  # Load configuration defaults
  Pkg::Config.load_defaults
  Pkg::Config.load_default_configs
  Pkg::Config.load_versioning
  Pkg::Config.load_overrides
  Pkg::Config.load_envvars
  Pkg::Config.issue_reassignments
  Pkg::Config.issue_deprecations
end
