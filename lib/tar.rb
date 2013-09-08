module Pkg
  class Tar
    $:.unshift(File.expand_path(File.dirname(__FILE__))) unless
      $:.include?(File.dirname(__FILE__)) || $:.include?(FILE.expand_path(File.dirname(__FILE__)))

    require 'util'
    require 'config'
    require 'fileutils'

    include FileUtils

    attr_accessor :files, :project, :version, :excludes, :target

    def initialize
      Pkg::Config.load_data if Pkg::Config.data.nil?

      @tar      = Pkg::Util.find_tool('tar', :required => true)
      @files    = Pkg::Config.data[:files]
      @project  = Pkg::Config.data[:project]
      @version  = Pkg::Config.data[:version]
      @excludes = Pkg::Config.data[:tar_excludes]
      @target   = File.join("pkg", "#{@project}-#{@version}.tar.gz")
    end

    def install_files_to(workdir)
      install = []
      # It is nice to use arrays in YAML to represent array content, but we used
      # to support a mode where a space-separated string was used.  Support both
      # to allow a gentle migration to a modern style...
      patterns =
        case @files
        when String
          STDERR.puts "warning: `files` should be an array, not a string"
          @files.split(' ')
        when Array
          @files
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
        if File.directory?(pattern) and not Pkg::Util.empty_dir?(patterm)
          install << Dir[pattern + "/**/*"]
        else
          install << pattern
        end
      end

      # Transfer all the files and symlinks into the working directory...
      install = install.select { |x| File.file?(x) or File.symlink?(x) or Pkg::Util.empty_dir?(x) }

      install.each do |file|
        if Pkg::Util.empty_dir?(file)
          mkpath(File.join(workdir, file), :verbose => false)
        else
          mkpath(File.dirname( File.join(workdir, file) ), :verbose => false)
          cp_p(file, File.join(workdir, file), :verbose => false)
        end
      end
    end

    def tar_c(target, workdir)
      Dir.chdir File.dirname(workdir) do
        %x[#{@tar} --exclude #{@excludes.join(" --exclude ")} -zcf '#{target}' #{File.basename(workdir)}]
      end
    end

    def clean_up(workdir)
      rm_rf workdir
    end

    def pkg!
      workdir = File.join(Pkg::Util.mktemp, "#{@project}-#{@version}")
      mkpath workdir
      install_files_to workdir
      tar_c @target, workdir
      clean_up
    end

  end
end

namespace :package do
  desc "Create a source tar archive"
  task :tar => [ :clean ] do


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

