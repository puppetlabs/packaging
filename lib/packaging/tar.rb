module Pkg
  class Tar
    require 'fileutils'
    require 'pathname'
    include FileUtils

    attr_accessor :files, :project, :version, :excludes, :target, :templates
    attr_reader :tar

    def initialize
      @tar      = Pkg::Util.find_tool('tar', :required => true)
      @project  = Pkg::Config.project
      @version  = Pkg::Config.version
      @files    = Pkg::Config.files
      @excludes = Pkg::Config.tar_excludes
      @target   = File.join(Pkg::Config.project_root, "pkg", "#{@project}-#{@version}.tar.gz")
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
      cd Pkg::Config.project_root do
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

    # Given the tar object's template files (assumed to be in Pkg::Config.project_root), transform
    # them, removing the originals. If workdir is passed, assume Pkg::Config.project_root
    # exists in workdir
    def template(workdir=nil)
      workdir ||= Pkg::Config.project_root
      @templates.each do |t|

        target_file = File.join(File.dirname(t), File.basename(t).sub(File.extname(t),""))
        root = Pathname.new(Pkg::Config.project_root)

        rel_path_to_erb = Pathname.new(t).relative_path_from(root)
        rel_path_to_target = Pathname.new(target_file).relative_path_from(root)

        Pkg::Util.erb_file(File.join(workdir,rel_path_to_erb.to_path), File.join(workdir, rel_path_to_target.to_path), :remove_orig => true, :binding => Pkg::Config.get_binding)
      end
    end

    def tar(target, source)
      mkpath File.dirname(target)
      Dir.chdir File.dirname(source) do
        %x[#{@tar} #{@excludes.map{ |x| (" --exclude #{x} ") }.join if @excludes} -zcf '#{File.basename(target)}' #{File.basename(source)}]
        mv File.basename(target), target
      end
    end

    def clean_up(workdir)
      rm_rf workdir
    end

    def pkg!
      workdir = File.join(Pkg::Util.mktemp, "#{@project}-#{@version}")
      mkpath workdir
      self.install_files_to workdir
      self.template(workdir)
      self.tar(@target, workdir)
      self.clean_up workdir
    end

  end
end

