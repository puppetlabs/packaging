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
    # tools themselves. If the template is a source/target combination, it is
    # returned to the array untouched.
    def expand_templates
      @templates.map! do |tempfile|
        if tempfile.is_a?(String)
          # Expand possible globs to all matching entries
          Dir.glob(File.join(Pkg::Config::project_root, tempfile))
        elsif tempfile.is_a?(Hash)
          tempfile
        end
      end
      @templates.flatten!

      # Reject matches that are templates from packaging itself. These will contain the packaging root.
      # These tend to come from the current tar.rake implementation.
      @templates.reject! { |temp| temp.is_a?(String) && temp.match(/#{Pkg::Config::packaging_root}/) }
    end

    # Given the tar object's template files (assumed to be in Pkg::Config.project_root), transform
    # them, removing the originals. If workdir is passed, assume Pkg::Config.project_root
    # exists in workdir
    def template(workdir=nil)
      workdir ||= Pkg::Config.project_root
      root = Pathname.new(Pkg::Config.project_root)

      template_list = []
      usage_count_map = Hash.new(0)

      # Create Array of template/target pairs and a map where template_file keys
      # have usage count balues.
      @templates.each do |cur_template|
        # Templates can be either a string or a hash of source and target. If it
        # is a string, the target is assumed to be the same path as the
        # source,with the extension removed. If it is a hash, we assume nothing
        # and use the provided source and target.
        if cur_template.is_a?(String)
          template_file = File.expand_path(cur_template)
          target_file = template_file.sub(File.extname(template_file),"")
        elsif cur_template.is_a?(Hash)
          template_file = File.expand_path(cur_template["source"])
          target_file = File.expand_path(cur_template["target"])
        end
        template_list << [template_file, target_file]

        usage_count_map[template_file] += 1
      end

      template_list.each do |template_file, target_file|
        # Check usage count for the given template file, if more than one then
        # don't remove the working directory copy.
        remove_workdir_copy = true
        if usage_count_map[template_file] > 1
          remove_workdir_copy = false
        end

        # Decrement usage_count_map to allow the next loop iteration that sees
        # it to remove the template_file from workdir.
        usage_count_map[template_file] -= 1

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
        if File.exist?(File.join(workdir,rel_path_to_template))
          mkpath(File.dirname( File.join(workdir, rel_path_to_target) ), :verbose => false)
          Pkg::Util::File.erb_file(File.join(workdir,rel_path_to_template), File.join(workdir, rel_path_to_target), remove_workdir_copy, :binding => Pkg::Config.get_binding)
        elsif File.exist?(File.join(root,rel_path_to_template))
          mkpath(File.dirname( File.join(workdir, rel_path_to_target) ), :verbose => false)
          Pkg::Util::File.erb_file(File.join(root,rel_path_to_template), File.join(workdir, rel_path_to_target), false, :binding => Pkg::Config.get_binding)
        else
          fail "Expected to find #{template_file} in #{root} for templating. But it was not there. Maybe you deleted it?"
        end
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

