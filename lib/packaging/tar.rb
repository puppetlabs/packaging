module Pkg
  class Tar
    require 'fileutils'

    include FileUtils

    attr_accessor :files, :project, :version, :excludes, :target
    attr_reader :tar

    def initialize
      @tar      = Pkg::Util.find_tool('tar', :required => true)
      @project  = Pkg::Config.project
      @version  = Pkg::Config.version
      @files    = Pkg::Config.files
      @excludes = Pkg::Config.tar_excludes
      @target   = File.join(Pkg::PROJECT_ROOT, "pkg", "#{@project}-#{@version}.tar.gz")
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
      cd Pkg::PROJECT_ROOT do
        patterns.each do |pattern|
          if File.directory?(pattern) and not Pkg::Util.empty_dir?(pattern)
            install << Dir[pattern + "/**/*"]
          else
            install << pattern
          end
        end
        install.flatten!

        # Transfer all the files and symlinks into the working directory...
        install = install.select { |x| File.file?(x) or File.symlink?(x) or Pkg::Util.empty_dir?(x) }

        install.each do |file|
          if Pkg::Util.empty_dir?(file)
            mkpath(File.join(workdir, file), :verbose => false)
          else
            mkpath(File.dirname( File.join(workdir, file) ), :verbose => false)
            cp(file, File.join(workdir, file), :verbose => false, :preserve => true)
          end
        end
      end
    end

    def tar(target, source)
      mkpath File.dirname(target)
      Dir.chdir File.dirname(source) do
        %x[#{@tar} #{@excludes.map{ |x| (" --exclude #{x}") } if @excludes} -zcf '#{File.basename(target)}' #{File.basename(source)}]
        mv File.basename(target), target
      end
    end

    def clean_up(workdir)
      rm_rf workdir
    end

    def pkg!
      workdir = File.join(Pkg::Util.mktemp, "#{@project}-#{@version}")
      mkpath workdir
      install_files_to workdir
      tar @target, workdir
      clean_up workdir
    end

  end
end

