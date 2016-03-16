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
      # It is nice to use arrays in YAML to represent array content, but we used
      # to support a mode where a space-separated string was used.  Support both
      # to allow a gentle migration to a modern style...
      patterns =
        case @files
        when String
          $stderr.puts "warning: `files` should be an array, not a string"
          @files.split(' ')
        when Array
          @files
        else
          raise "`files` must be a string or an array!"
        end

      Pkg::Util::File.install_files_into_dir(patterns, workdir)
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
    def template(workdir = nil)
      workdir ||= Pkg::Config.project_root
      root = Pathname.new(Pkg::Config.project_root)

      # Templates can be either a string or a hash of source and target. If it
      # is a string, the target is assumed to be the same path as the
      # source,with the extension removed. If it is a hash, we assume nothing
      # and use the provided source and target.
      @templates.each do |cur_template|
        if cur_template.is_a?(String)
          template_file = File.expand_path(cur_template)
          target_file = template_file.sub(File.extname(template_file), "")
        elsif cur_template.is_a?(Hash)
          template_file = File.expand_path(cur_template["source"])
          target_file = File.expand_path(cur_template["target"])
        end

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
        if File.exist?(File.join(workdir, rel_path_to_template))
          mkpath(File.dirname(File.join(workdir, rel_path_to_target)), :verbose => false)
          Pkg::Util::File.erb_file(File.join(workdir, rel_path_to_template), File.join(workdir, rel_path_to_target), true, :binding => Pkg::Config.get_binding)
        elsif File.exist?(File.join(root, rel_path_to_template))
          mkpath(File.dirname(File.join(workdir, rel_path_to_target)), :verbose => false)
          Pkg::Util::File.erb_file(File.join(root, rel_path_to_template), File.join(workdir, rel_path_to_target), false, :binding => Pkg::Config.get_binding)
        else
          fail "Expected to find #{template_file} in #{root} for templating. But it was not there. Maybe you deleted it?"
        end
      end
    end

    def tar(target, source)
      mkpath File.dirname(target)
      cd File.dirname(source) do
        %x(#{@tar} #{@excludes.map { |x| (" --exclude #{x} ") }.join if @excludes} -zcf '#{File.basename(target)}' '#{File.basename(source)}')
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
      self.tar(@target, workdir)
      self.clean_up workdir
    end

  end
end

