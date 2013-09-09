module Pkg

  LIBDIR = File.expand_path(File.dirname(__FILE__))

  $:.unshift(LIBDIR) unless
    $:.include?(File.dirname(__FILE__)) || $:.include?(LIBDIR)


  # It is really quite unsafe to assume github.com/puppetlabs/packaging has been
  # cloned into $PROJECT_ROOT/ext/packaging even if it has _always_ been the
  # default location. We really don't have much choice as of this moment but to
  # assume this directory, or assume the user has passed in the correct one via
  # ENV['PROJECT_ROOT']. It is critical we have the correct $PROJECT_ROOT, because
  # we get all of the package versioning from the `git-describe` of $PROJECT. If we
  # assume $PROJECT_ROOT/ext/packaging, it means packaging/lib/packaging.rb is
  # three subdirectories below $PROJECT_ROOT, e.g.,
  # $PROJECT_ROOT/ext/packaging/lib/packaging.rb.
  #
  PROJECT_ROOT = ENV['PROJECT_ROOT'] || File.expand_path(File.join(LIBDIR, "..","..",".."))

  require 'packaging/util'
  require 'packaging/config'
  require 'packaging/tar'

end
