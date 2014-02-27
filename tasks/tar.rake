namespace :package do
  desc "Create a source tar archive"
  task :tar => [ :clean ] do

    if Pkg::Config.pre_tar_task
      invoke_task(Pkg::Config.pre_tar_task)
    end

    Rake::Task["package:doc"].invoke if Pkg::Config.build_doc

    tar = Pkg::Tar.new

    # If the user has specified templates via config file, they will be ack'd
    # by the tar class. Otherwise, we load what we consider to be the "default"
    # set, which is default for historical purposes.
    #
    tar.templates ||= Dir[File.join(Pkg::Config.project_root, "ext", "**", "*.erb")].select { |i| i !~ /ext\/packaging|ext\/osx/ }


    # If the user has specified things to exclude via config file, they will be
    # honored by the tar class, but we also always exclude the packaging repo.
    #
    tar.excludes << "ext/packaging"

    # This is to support packages that only burn-in the version number in the
    # release artifact, rather than storing it two (or more) times in the
    # version control system.  Razor is a good example of that; see
    # https://github.com/puppetlabs/Razor/blob/master/lib/project_razor/version.rb
    # for an example of that this looks like.
    #
    # If you set this the version will only be modified in the temporary copy,
    # with the intent that it never change the official source tree.
    Pkg::Util::Version.versionbump(workdir) if Pkg::Config.update_version_file

    tar.pkg!

    puts "Wrote #{`pwd`.strip}/pkg/#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz"
  end
end

namespace :pl do
  task :tar => ["package:tar"]
end

