module Pkg::Util::Prompt
  class << self
    # This is the most basic prompt, which just asks a user if they want to continue or not
    def ask_yes_or_no
      # Answers can be overridden with an environment variable
      return Pkg::Util.boolean_value(ENV['ANSWER_OVERRIDE']) unless ENV['ANSWER_OVERRIDE'].nil?

      printf 'yes or no? > '
      $stdout.flush
      answer = $stdin.gets.downcase.strip

      return true if answer =~ /^y$|^yes$/
      return false if answer =~ /^n$|^no$/
      puts %Q{"#{answer}" is invalid. Please say yes or no.}
      ask_yes_or_no
    end

    def confirm_ship(files)
      $stdout.puts "The following files have been built and are ready to ship:"
      files.each { |file| $stdout.puts "\t#{file}\n" unless File.directory?(file) }
      $stdout.puts "Ship these files?"
      ask_yes_or_no
    end

    def confirm_tag(tag)
      $stdout.puts %Q{You've checked out tag "#{tag}".}
      $stdout.puts %Q{Is this what you want to ship?}
      ask_yes_or_no
    end
  end
end