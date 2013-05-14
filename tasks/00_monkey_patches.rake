
# This monkey patch allows us to prepend blocks to a rake task's execution blocks

module Rake
  class Task
    def unshift(deps=nil, &block)
      @prerequisites |= deps if deps
      @actions.unshift(block) if block_given?
      self
    end
  end
end

