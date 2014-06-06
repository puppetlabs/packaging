require 'rubygems'
require 'rspec'
require 'pathname'
require 'rake'

SPECDIR = Pathname(__FILE__).dirname
PROJECT_ROOT = File.expand_path(File.join(Pathname(__FILE__).dirname, ".."))
FIXTURES = File.join(SPECDIR, 'fixtures')

require File.join(SPECDIR, '..', 'lib', 'packaging.rb')

def load_task(name)
  return false if (@loaded ||= {})[name]
  load File.join(SPECDIR, '..', 'tasks', name)
  @loaded[name] = true
end

def reset_env(keys)
  keys.each do |key|
    ENV[key] = nil
  end
end
