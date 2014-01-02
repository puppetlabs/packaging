namespace :package do
  desc "Create a source tar archive"
  task :tar => [ :clean ] do

    if Pkg::Config.pre_tar_task
      invoke_task(Pkg::Config.pre_tar_task)
    end

    Rake::Task["package:doc"].invoke if Pkg::Config.build_doc

    tar = Pkg::Tar.new

    if Pkg::Config.templates
      fail "templates must be an array" unless Pkg::Config.templates.is_a?(Array)
      tar.templates = Pkg::Config.templates.dup
    else
      tar.templates = Dir[File.join(Pkg::Config.project_root, "ext", "**", "*.erb")].select { |i| i !~ /ext\/packaging|ext\/osx/ }
    end

    if Pkg::Config.tar_excludes
      if Pkg::Config.tar_excludes.is_a?(Array)
        tar.excludes = Pkg::Config.tar_excludes.dup
      else
        warn "!! tar_excludes should be an array"
        tar.excludes = Pkg::Config.tar_excludes.split(' ')
      end
    end
    # This is to support packages that only burn-in the version number in the
    # release artifact, rather than storing it two (or more) times in the
    # version control system.  Razor is a good example of that; see
    # https://github.com/puppetlabs/Razor/blob/master/lib/project_razor/version.rb
    # for an example of that this looks like.
    #
    # If you set this the version will only be modified in the temporary copy,
    # with the intent that it never change the official source tree.
    Rake::Task["package:versionbump"].invoke(workdir) if Pkg::Config.update_version_file

    tar.pkg!

    puts "Wrote #{`pwd`.strip}/pkg/#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz"
  end
end

namespace :pl do
  task :tar => ["package:tar"]
end

