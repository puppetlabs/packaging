# Utility methods for handling system calls and interactions

module Pkg::Util::Execution

  class << self

    # Alias to $?.success? that makes success? slightly easier to test and stub
    # If immediately run, $? will not be instanciated, so only call success? if
    # $? exists, otherwise return nil
    def success?(statusobject = $?)
      return statusobject.success?
    end

    # ex combines the behavior of `%x{cmd}` and rake's `sh "cmd"`. `%x{cmd}` has
    # the benefit of returning the standard out of an executed command, enabling us
    # to query the file system, e.g. `contents = %x{ls}`. The drawback to `%x{cmd}`
    # is that on failure of a command (something returned non-zero) the return of
    # `%x{cmd}` is just an empty string. As such, we can't know if we succeeded.
    # Rake's `sh "cmd"`, on the other hand, will raise a RuntimeError if a command
    # does not return 0, but doesn't return any of the stdout from the command -
    # only true or false depending on its success or failure. With `ex(cmd)` we
    # purport to both return the results of the command execution (ala `%x{cmd}`)
    # while also raising an exception if a command does not succeed (ala `sh "cmd"`).
    def ex(command, debug = false)
      puts "Executing '#{command}'..." if debug
      ret = `#{command}`
      unless Pkg::Util::Execution.success?
        raise RuntimeError
      end

      if debug
        puts "Command '#{command}' returned:"
        puts ret
      end

      ret
    end

    # Turns out trying to change ex to use Open3 is SUPER DANGEROUS and destructive
    # in ways I hadn't imagined. I'm going to add a new method here instead and start
    # converting code to use that so I don't break more than I plan to.
    def capture3(command, debug = false)
      require 'open3'
      puts "Executing '#{command}'..." if debug
      stdout, stderr, ret = Open3.capture3(command)
      unless Pkg::Util::Execution.success?(ret)
        raise "#{stdout}#{stderr}"
      end

      if debug
        puts "Command '#{command}' returned:"
        puts stdout
      end

      return stdout, stderr, ret
    end

    # Loop a block up to the number of attempts given, exiting when we receive success
    # or max attempts is reached. Raise an exception unless we've succeeded.
    def retry_on_fail(args, &blk)
      success = FALSE
      exception = ''

      if args[:times].respond_to?(:times) and block_given?
        args[:times].times do |i|
          if args[:delay]
            sleep args[:delay]
          end

          begin
            blk.call
            success = TRUE
            break
          rescue => err
            puts "An error was encountered evaluating block. Retrying.."
            exception = err.to_s + "\n" + err.backtrace.join("\n")
          end
        end
      else
        fail "retry_on_fail requires and arg (:times => x) where x is an Integer/Fixnum, and a block to execute"
      end
      fail "Block failed maximum of #{args[:times]} tries. Exiting..\nLast failure was: #{exception}" unless success
    end
  end
end
