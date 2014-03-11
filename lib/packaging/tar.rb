module Pkg
  class Tar
    require 'fileutils'
    require 'pathname'
    include FileUtils

    attr_accessor :files, :project, :version, :excludes, :target, :templates
    attr_reader :tar

    def initialize
      @tar      = Pkg::Util::Tool.find_tool('tar', :required => true)
      @project  = Pkg::Config.project
      @version  = Pkg::Config.version
      @files    = Pkg::Config.files
      @target   = File.join(Pkg::Config.project_root, "pkg", "#{@project}-#{@version}.tar.gz")

      # We require that the excludes list be a string (which is space
      # separated, we hope)(deprecated) or an array.
      #
      if Pkg::Config.tar_excludes
        if Pkg::Config.tar_excludes.is_a?(String)
          warn "warning: `tar_excludes` should be an array, not a string"
          @excludes = Pkg::Config.tar_excludes.split(' ')
        elsif Pkg::Config.tar_excludes.is_a?(Array)
          @excludes = Pkg::Config.tar_excludes
        else
          fail "Tarball excludes must either be an array or a string, not #{@excludes.class}"
        end
      else
        @excludes = []
      end

      # On the other hand, support for explicit templates started with Arrays,
      # so that's all we support.
      #
      if Pkg::Config.templates
        @templates = Pkg::Config.templates.dup
        fail "templates must be an array" unless @templates.is_a?(Array)
        expand_templates
      end
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
          if File.directory?(pattern) and not Pkg::Util::File.empty_dir?(pattern)
            install << Dir[pattern + "/**/*"]
          else
            install << Dir[pattern]
          end
        end
        install.flatten!

        # Transfer all the files and symlinks into the working directory...
        install = install.select { |x| File.file?(x) or File.symlink?(x) or Pkg::Util::File.empty_dir?(x) }

        install.each do |file|
          if Pkg::Util::File.empty_dir?(file)
            mkpath(File.join(workdir, file), :verbose => false)
          else
            mkpath(File.dirname( File.join(workdir, file) ), :verbose => false)
            cp(file, File.join(workdir, file), :verbose => false, :preserve => true)
          end
        end
      end
    end

    # The templates of a project can include globs, which may expand to an
    # arbitrary number of files. This method expands all of the templates using
    # Dir.glob and then filters out any templates that live in the packaging
    # tools themselves.
    def expand_templates
      @templates.map! { |tempfile| Dir.glob(File.join(Pkg::Config::project_root, tempfile)) }
      @templates.flatten!
      @templates.reject! { |temp| temp.match(/#{Pkg::Config::packaging_root}/) }
    end

    # Given the tar object's template files (assumed to be in Pkg::Config.project_root), transform
    # them, removing the originals. If workdir is passed, assume Pkg::Config.project_root
    # exists in workdir
    def template(workdir=nil)
      workdir ||= Pkg::Config.project_root
      root = Pathname.new(Pkg::Config.project_root)
      @templates.each do |template_file|

        template_file = File.expand_path(template_file)

        target_file = template_file.sub(File.extname(template_file),"")

        #   We construct paths to the erb template and its proposed target file
        #   relative to the project root, *not* fully qualified. This allows us
        #   to, given a temporary workdir containing a copy of the project,
        #   construct the full path to the erb and target file inside the
        #   temporary workdir.
        #
        rel_path_to_template = Pathname.new(template_file).relative_path_from(root).to_s
        rel_path_to_target = Pathname.new(target_file).relative_path_from(root).to_s

        #   What we pass to Pkg::util::File.erb_file are the paths to the erb
        #   and target inside of a temporary project directory. We are, in
        #   essence, templating "in place." This is why we remove the original
        #   files - they're not the originals in the authoritative project
        #   directory, but the originals in the temporary working copy.
        Pkg::Util::File.erb_file(File.join(workdir,rel_path_to_template), File.join(workdir, rel_path_to_target), true, :binding => Pkg::Config.get_binding)
      end
    end

    def tar(target, source)
      mkpath File.dirname(target)
      cd File.dirname(source) do
        %x[#{@tar} #{@excludes.map{ |x| (" --exclude #{x} ") }.join if @excludes} -zcf '#{File.basename(target)}' '#{File.basename(source)}']
        unless $?.success?
          fail "Failed to create .tar.gz archive with #{@tar}. Please ensure the tar command in your path accepts the flags '-c', '-z', and '-f'"
        end
        mv File.basename(target), target
      end
    end

    def clean_up(workdir)
      rm_rf workdir
    end

    def pkg!
      workdir = File.join(Pkg::Util::File.mktemp, "#{@project}-#{@version}")
      mkpath workdir
      self.install_files_to workdir
      self.template(workdir)
      Pkg::Util::Version.versionbump(workdir) if Pkg::Config.update_version_file
      self.tar(@target, workdir)
      self.clean_up workdir
    end

  end
end

