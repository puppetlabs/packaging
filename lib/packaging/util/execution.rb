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
      # The following is for windows systems attempting to use
      # packaging. In that scenario, it's often that C:\Program Files
      # is a part of the path to executables.
      #
      # The space in program files causes execution to fail in ruby
      #
      # To remedy the space in C:\Program Files, we use the windows environment var
      # %ProgramFiles% in it's place. Unfortunately, in order to use that env var we
      # also need to escape the system call with "s. Even more unfortunate: we can _only_
      # escape the executable path, not the whole command string, otherwise windows will
      # bail out of execution.
      #
      # So here we are: the following checks if the command starts with C:/Program Files,
      # then replaces that string with %ProgramFiles%. Then splits the command string using
      # spaces as a delimeter (now that there is no space in C:/Program Files) and surrounds
      # the first section (the executable) with "s.
      #
      #                                                  - Sean P. McDonald 8/3/18
      if command.start_with?("C:/Program Files")
        command_parts = command.gsub("C:/Program Files", "%ProgramFiles%").split(' ')
        command_parts[0] = "\"" + command_parts[0] + "\""
        command = command_parts.join(' ')
      elsif command.start_with?("C:/Program Files (x86)")
        command_parts = command.gsub("C:/Program Files (x86)", "%ProgramFiles(x86)%").split(' ')
        command_parts[0] = "\"" + command_parts[0] + "\""
        command = command_parts.join(' ')
      end
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
