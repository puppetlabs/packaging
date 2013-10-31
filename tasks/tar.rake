namespace :package do
  desc "Create a source tar archive"
  task :tar => [ :clean ] do

    if @build.pre_tar_task
      invoke_task(@build.pre_tar_task)
    end

    Rake::Task["package:doc"].invoke if @build.build_doc
    tar = ENV['TAR'] || 'tar'
    workdir = "pkg/#{@build.project}-#{@build.version}"
    mkdir_p(workdir)

    # The list of files to install in the tarball
    install = FileList.new

    # It is nice to use arrays in YAML to represent array content, but we used
    # to support a mode where a space-separated string was used.  Support both
    # to allow a gentle migration to a modern style...
    patterns =
      case @build.files
      when String
        STDERR.puts "warning: `files` should be an array, not a string"
        @build.files.split(' ')

      when Array
        @build.files

      else
        raise "`files` must be a string or an array!"
      end

    # We need to add our list of file patterns from the configuration; this
    # used to be a list of "things to copy recursively", which would install
    # editor backup files and other nasty things.
    #
    # This handles that case correctly, with a deprecation warning, to augment
    # our FileList with the right things to put in place.
    #
    # Eventually, when all our projects are migrated to the new standard, we
    # can drop this in favour of just pushing the patterns directly into the
    # FileList and eliminate many lines of code and comment.
    patterns.each do |pattern|
      if File.directory?(pattern) and not Dir[pattern + "/**/*"].empty?
        install.add(pattern + "/**/*")
      else
        install.add(pattern)
      end
    end

    # Transfer all the files and symlinks into the working directory...
    install = install.select { |x| File.file?(x) or File.symlink?(x) or empty_dir?(x) }

    install.each do |file|
      if empty_dir?(file)
        mkpath(File.join(workdir,file), :verbose => false)
      else
        mkpath(File.dirname( File.join(workdir, file) ), :verbose => false)
        cp_p(file, File.join(workdir, file), :verbose => false)
      end
    end

    tar_excludes = @build.tar_excludes.nil? ? [] : @build.tar_excludes.split(' ')
    tar_excludes << "ext/#{@build.packaging_repo}"
    Rake::Task["package:template"].invoke(workdir)

    # This is to support packages that only burn-in the version number in the
    # release artifact, rather than storing it two (or more) times in the
    # version control system.  Razor is a good example of that; see
    # https://github.com/puppetlabs/Razor/blob/master/lib/project_razor/version.rb
    # for an example of that this looks like.
    #
    # If you set this the version will only be modified in the temporary copy,
    # with the intent that it never change the official source tree.
    Rake::Task["package:versionbump"].invoke(workdir) if @build.update_version_file

    cd "pkg" do
      sh "#{tar} --exclude #{tar_excludes.join(" --exclude ")} -zcf '#{@build.project}-#{@build.version}.tar.gz' #{@build.project}-#{@build.version}"
    end
    rm_rf(workdir)
    puts
    puts "Wrote #{`pwd`.strip}/pkg/#{@build.project}-#{@build.version}.tar.gz"
  end
end

namespace :pl do
  task :tar => ["package:tar"]
end

