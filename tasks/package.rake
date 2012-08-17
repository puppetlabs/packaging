namespace :package do
  task :build_environment do
    unless ENV['FORCE'] == '1'
      modified = `git status --porcelain | sed -e '/^\?/d'`
      if modified.split(/\n/).length != 0
        puts <<-HERE
!! ERROR: Your git working directory is not clean. You must
!! remove or commit your changes before you can create a package:

#{`git status | grep '^#'`.chomp}

!! To override this check, set FORCE=1 -- e.g. `rake package:deb FORCE=1`
        HERE
        raise
      end
    end
  end
end
