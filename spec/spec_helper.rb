require 'rubygems'
require 'rspec'
require 'pathname'
require 'rake'
require 'stringio'

SPECDIR = Pathname(__FILE__).dirname
PROJECT_ROOT = File.expand_path(File.join(Pathname(__FILE__).dirname, ".."))
FIXTURES = File.join(SPECDIR, 'fixtures')

require File.join(SPECDIR, '..', 'lib', 'packaging.rb')

def load_task(name)
  return false if (@loaded ||= {})[name]
  load File.join(SPECDIR, '..', 'tasks', name)
  @loaded[name] = true
end

# capture_stdout, #capture_stderr, and #fake_stdin all wrap
# and encapsulate the i/o streams in their names. They take
# a block and run it with those steams wrapped up in simple
# StringIO objects, so that the flow of using a command-line
# style application can be monitored and tested.
def capture_stdout(&blk)
  $stdout = fake = StringIO.new
  blk.call
  fake.string
ensure
  $stdout = STDOUT
end

def capture_stderr(&blk)
  $stderr = fake = StringIO.new
  blk.call
  fake.string
ensure
  $stderr = STDERR
end

def fake_stdin(*args)
  begin
    $stdin = StringIO.new
    $stdin.puts(args.shift) until args.empty?
    $stdin.rewind
    yield
  ensure
    $stdin = STDIN
  end
end
