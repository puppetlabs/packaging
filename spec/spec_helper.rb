require 'rubygems'
require 'rspec'
require 'pathname'
require 'rake'

SPECDIR = Pathname(__FILE__).dirname

def require_task(name)
  return false if (@loaded ||= {})[name]
  load SPECDIR + '..' + 'tasks' + "#{name}.rake"
  @loaded[name] = true
end
