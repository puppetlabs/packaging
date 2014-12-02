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
    def ex(command)
      ret = `#{command}`
      unless Pkg::Util::Execution.success?
        raise RuntimeError
      end
      ret
    end

  end
end
