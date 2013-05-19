module Rake
  class Task
    # This allows us to keep track of how many "tasks" a task will actually
    # execute as part of the task itself
    attr_accessor :count

    # This method allows us to prepend blocks to a rake task's execution blocks
    def unshift(deps=nil, &block)
      @prerequisites |= deps if deps
      @actions.unshift(block) if block_given?
      self
    end
  end
end

