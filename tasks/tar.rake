namespace :package do
  desc "Create a source tar archive"
  task :tar => [:clean] do
    if Pkg::Config.pre_tar_task
      Pkg::Util::RakeUtils.invoke_task(Pkg::Config.pre_tar_task)
    end

    Rake::Task["package:doc"].invoke if Pkg::Config.build_doc

    tar = Pkg::Tar.new

    # If the user has specified templates via config file, they will be ack'd
    # by the tar class. Otherwise, we load what we consider to be the "default"
    # set, which is default for historical purposes.
    #
    tar.templates ||= Dir[File.join(Pkg::Config.project_root, "ext", "**", "*.erb")].reject { |i| i =~ /ext\/packaging|ext\/osx/ }

    tar.pkg!

    puts "Wrote #{%x(pwd).strip}/pkg/#{Pkg::Config.project}-#{Pkg::Config.version}.tar.gz"
  end
end

namespace :pl do
  task :tar => ["package:tar"]
end

