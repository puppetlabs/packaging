namespace :package do
  desc "Create a source tar archive"
  task :tar => [ :clean ] do

    if @build.pre_tar_task
      invoke_task(@build.pre_tar_task)
    end

    Rake::Task["package:doc"].invoke if @build.build_doc

    tar = Pkg::Tar.new

    templates = Dir[File.join(Pkg::PROJECT_ROOT, 'ext', '**', '*.erb')].select { |i| i !~ /packaging|osx/ }

    templates.each do |e|
      t = Pkg::Util.erb_file(e, nil, :remove_orig => true)
      tar.files << t
      rm t
    end


    # This is to support packages that only burn-in the version number in the
    # release artifact, rather than storing it two (or more) times in the
    # version control system.  Razor is a good example of that; see
    # https://github.com/puppetlabs/Razor/blob/master/lib/project_razor/version.rb
    # for an example of that this looks like.
    #
    # If you set this the version will only be modified in the temporary copy,
    # with the intent that it never change the official source tree.
    Rake::Task["package:versionbump"].invoke(workdir) if @build.update_version_file

    puts "Wrote #{`pwd`.strip}/pkg/#{@build.project}-#{@build.version}.tar.gz"
  end
end

namespace :pl do
  task :tar => ["package:tar"]
end

