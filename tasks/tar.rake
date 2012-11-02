namespace :package do
  desc "Create a source tar archive"
  task :tar => [ :clean ] do
    Rake::Task["package:doc"].invoke if @build_doc
    tar = ENV['TAR'] || 'tar'
    workdir = "pkg/#{@name}-#{@version}"
    mkdir_p(workdir)

    # The list of files to install in the tarball
    install = FileList.new

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
    patterns = @files.split(' ').each do |pattern|
      if File.directory?(pattern)
        install.add(pattern + "/**/*")
      else
        install.add(pattern)
      end
    end

    # Transfer all the files and symlinks into the working directory...
    install = install.select {|x| File.file?(x) or File.symlink?(x) }
    sh "tar c #{install} | tar x -C #{workdir}"

    tar_excludes = @tar_excludes.nil? ? [] : @tar_excludes.split(' ')
    tar_excludes << "ext/#{@packaging_repo}"
    Rake::Task["package:template"].invoke(workdir)
    cd "pkg" do
      sh "#{tar} --exclude #{tar_excludes.join(" --exclude ")} -zcf #{@name}-#{@version}.tar.gz #{@name}-#{@version}"
    end
    rm_rf(workdir)
    puts
    puts "Wrote #{`pwd`.strip}/pkg/#{@name}-#{@version}.tar.gz"
  end
end
