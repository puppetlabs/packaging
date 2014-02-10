require 'rubygems'
require 'rspec'
require 'pathname'
require 'rake'

SPECDIR = Pathname(__FILE__).dirname
FIXTURES = File.join(SPECDIR, 'fixtures')

require File.join(SPECDIR, '..', 'lib', 'packaging.rb')

def load_task(name)
  return false if (@loaded ||= {})[name]
  load File.join(SPECDIR, '..', 'tasks', name)
  @loaded[name] = true
end
