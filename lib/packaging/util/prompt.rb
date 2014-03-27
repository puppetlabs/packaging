module Pkg::Util::Prompts
  class << self
    # Are these methods repetitive? Sure.
    # But let's get the workflow laid out before we put lipstick on this pig.

    def confirm_ship(files)
      $stdout.puts "The following files have been built and are ready to ship:"
      files.each { |file| STDOUT.puts "\t#{file}\n" unless File.directory?(file) }
      $stdout.puts "Ship these files?? [y,n]"
      ask_yes_or_no
    end

    def confirm_tag
      type = Pkg::Util::Version.git_ref_type
      desc = Pkg::Util::Version.git_describe
      case type
      when 'tag'
        $stdout.puts "You've checked out tag #{desc}; is this what you meant to ship?"
      else
        $stdout.puts "It looks like you're not on a tag (#{desc}). Whoops?"
        $stdout.puts "Is this really what you want to do? (FYI: I think you should probably say 'no')"
      end
      ask_yes_or_no
    end

    def confirm_branch
      if Pkg::Util::Version.git_detached?
        msg = "You're shipping, but you're detached from HEAD."
      else
        msg = "You're shipping from #{Pkg::Util::Version.git_branch}"
      end

      msg += "\n(Would you rather ship from branch 'stable'?)" unless Pkg::Util::Version.git_stable?

      $stdout.puts msg
      $stdout.puts "\nIs this where you really want to ship from?"
      ask_yes_or_no
    end

    def ask_yes_or_no
      spacer = ('-' * 24)
      spacer += "\n\n"

      return Pkg::Util.boolean_value(ENV['ANSWER_OVERRIDE']) unless ENV['ANSWER_OVERRIDE'].nil?
      printf 'yes or no? > '
      answer = STDIN.gets.downcase.chomp

      # Write a spacer between questions
      puts spacer

      return TRUE if answer =~ /^y$|^yes$/
      return FALSE if answer =~ /^n$|^no$/
      puts "Nope, try something like yes or no or y or n, etc:"
      ask_yes_or_no
    end
  end
end
