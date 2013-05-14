# Utility methods for working with Rake tasks
module RakeUtils

  # These are module-level utils
  class << self

    def find_task(name)
      Rake::Task.tasks.find{ |t| t.name == name }
    end

  end
end

