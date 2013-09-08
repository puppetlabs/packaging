module Pkg

  $:.unshift(File.expand_path(File.dirname(__FILE__))) unless
    $:.include?(File.dirname(__FILE__)) || $:.include?(FILE.expand_path(    File.dirname(__FILE__)))

  require 'packaging/util'
  require 'packaging/config'
  require 'packaging/tar'
end
