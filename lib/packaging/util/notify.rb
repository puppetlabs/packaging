module Pkg::Util::Notify
  class << self
    def not_on_tag
      $stderr.puts "It looks like you're not on a tag (#{Pkg::Util::Version.git_describe})? Whoops!"
    end

    def on_branch
      $stderr.puts "It looks you're trying to ship from a branch instead of a tag? Whoops!"
    end

    def display_branch
      if Pkg::Util::Version.git_detached?
        msg = "You're shipping detached from HEAD."
      else
        msg = "You're shipping from #{Pkg::Util::Version.git_branch}"
      end
      $stdout.puts
    end
  end
end
