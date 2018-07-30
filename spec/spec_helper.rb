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

RSpec.configure do |config|
  if Pkg::Util::OS.windows? && RUBY_VERSION =~ /^1\./
    require 'win32console'
    config.output_stream = $stdout
    config.error_stream = $stderr

    config.formatters.each do |f|
      if not f.instance_variable_get(:@output).kind_of?(::File)
        f.instance_variable_set(:@output, $stdout)
      end
    end
  end
end
