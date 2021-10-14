module Pkg
  ##
  #   This class is meant to encapsulate all of the data we know about a build invoked with
  #   `rake package:<build>` or `rake pl:<build>`. It can read in this data via a yaml file,
  #   have it set via accessors, and serialize it back to yaml for easy transport.
  #
  class Config
    require 'packaging/config/params.rb'
    require 'packaging/config/validations.rb'
    require 'yaml'

    class << self
      ##
      #   Returns a hash with string keys that maps instance variable
      #   names without "@"" to their corresponding values.
      #
      def instance_values
        Hash[instance_variables.map { |name| [name[1..-1], instance_variable_get(name)] }]
      end

      #   Every element in Pkg::Params::BUILD_PARAMS is a configurable setting
      #   for the build. We use Pkg::Params::BUILD_PARAMS as the source of
      #   truth for defining the the class instance variables and their
      #   accessors of the Pkg::Config class
      Pkg::Params::BUILD_PARAMS.each do |v|
        attr_accessor v
      end

      #   Return the binding of class context. Used for erb templates.
      #
      def get_binding
        return binding
      end

      ##
      #   Take a hash of Config parameters, and iterate over them, setting the
      #   value for each Config param to the corresponding hash key,value.
      #
      def config_from_hash(data = {})
        data.each do |param, value|
          if Pkg::Params::BUILD_PARAMS.include?(param.to_sym)
            self.instance_variable_set("@#{param}", value)
          else
            warn "Warning - No build data parameter found for '#{param}'. Perhaps you have an erroneous entry in your yaml file?"
          end
        end
      end

      ##
      # Load a yaml file and use its contents to set the values for Pkg::Config
      # class instance variables
      #
      def config_from_yaml(file)
        build_data = Pkg::Util::Serialization.load_yaml(file)
        config_from_hash(build_data)
      end

      ##
      # By default return a hash of the names, values of current Pkg::Config
      # instance variables. With :format => :yaml, write a yaml file containing
      # the current names,values of Pkg::Config class instance variables
      #
      def config(args = { :target => nil, :format => :hash })
        case args[:format]
          when :hash
            self.config_to_hash
          when :yaml
            self.config_to_yaml(args[:target])
        end
      end

      ##
      # For each platform we ship for, find paths to its artifact and repo_config (if applicable).
      # This is to be consumed by beaker and later replaced with our metadata service.
      #
      def platform_data
        # Return nil if something is not right..
        return nil unless self.project && self.ref &&
                          Pkg::Util::Net.check_host_ssh([self.builds_server]).empty?

        dir = "/opt/jenkins-builds/#{self.project}/#{self.ref}"
        cmd = "if [ -s \"#{dir}/artifacts\" ]; then cd #{dir};"\
              "find ./artifacts/ -mindepth 2 -type f; fi"
        artifacts, _ = Pkg::Util::Net.remote_execute(
                     self.builds_server,
                     cmd,
                     { capture_output: true }
                   )

        artifacts = artifacts.split("\n")
        data = {}
        artifacts.each do |artifact|
          # We need to preserve the original tag to make sure we look for
          # fedora repo configs in the 1.10.x branch of puppet-agent in
          # the correct place. For 5.x and 6.x release streams the f prefix
          # has been removed and so tag will equal original_tag
          original_tag = Pkg::Paths.tag_from_artifact_path(artifact)

          # Remove the f-prefix from the fedora platform tag keys so that
          # beaker can rely on consistent keys once we rip out the f for good
          tag = original_tag.sub(/fedora-f/, 'fedora-')

          data[tag] ||= {}

          platform, version, arch = Pkg::Platforms.parse_platform_tag(tag)
          package_format = Pkg::Platforms.get_attribute(tag, :package_format)

          # Skip this if it's an unversioned MSI. We create these to help
          # beaker install the msi without having to know any version
          # information, but we should report the versioned artifact in
          # platform_data
          next if platform =~ /^windows.*$/ &&
                  File.basename(artifact) == "#{self.project}-#{arch}.#{package_format}"

          # Sometimes we have source or debug packages. We don't want to save
          # these paths in favor of the artifact paths.
          if platform == 'solaris'
            next if version == '10' && File.extname(artifact) != '.gz'
            next if version == '11' && File.extname(artifact) != '.p5p'
          else
            next if File.extname(artifact) != ".#{package_format}"
          end

          # Don't want to include debian debug packages
          next if /-dbgsym/.match(File.basename(artifact))

          if /#{self.project}-[a-z]+/.match(File.basename(artifact))
            add_additional_artifact(data, tag, artifact.sub('artifacts/', ''))
            next
          end

          case package_format
          when 'deb'
            repo_config = "../repo_configs/deb/pl-#{self.project}-#{self.ref}-"\
                          "#{Pkg::Platforms.get_attribute(tag, :codename)}.list"
          when 'rpm'
            # Using original_tag here to not break legacy fedora repo targets
            unless tag.include? 'aix'
              repo_config = "../repo_configs/rpm/pl-#{self.project}-"\
                            "#{self.ref}-#{original_tag}.repo"
            end
          when 'swix', 'svr4', 'ips', 'dmg', 'msi'
            # No repo_configs for these platforms, so do nothing.
          else
            fail "Error: Unknown package format: '#{package_format}'. Maybe update PLATFORM_INFO?"
          end

          # handle the case where there are multiple artifacts but the artifacts are not
          # named based on project name (e.g. puppet-enterprise-vanagon).
          # In this case, the first one will get set as the artifact, everything else
          # will be in the additional artifacts
          if data[tag][:artifact].nil?
            data[tag][:artifact] = artifact.sub('artifacts/', '')
            data[tag][:repo_config] = repo_config
          else
            add_additional_artifact(data, tag, artifact.sub('artifacts/', ''))
          end
        end
        return data
      end

      # Add artifact to the `additional_artifacts` array in platform data.
      # This will not add noarch package paths for the same noarch package
      # multiple times.
      #
      # @param platform_data The platform data hash to update
      # @param tag the platform tag
      # @param artifact the path of the additional artifact path to add
      def add_additional_artifact(platform_data, tag, artifact)
        # Don't add noarch packages to additional_artifacts if the same package
        # is already the artifact
        if !platform_data[tag][:artifact].nil? && File.basename(platform_data[tag][:artifact]) == File.basename(artifact)
          return
        end

        platform_data[tag][:additional_artifacts] ||= []

        if platform_data[tag][:additional_artifacts].select { |a| File.basename(a) == File.basename(artifact) }.empty?
          platform_data[tag][:additional_artifacts] << artifact
        end

        # try to avoid empty entries in the yaml for more concise output
        if platform_data[tag][:additional_artifacts].empty?
          platform_data[tag][:additional_artifacts] = nil
        end
      end

      ##
      # Return a hash of all build parameters and their values, nil if unassigned.
      #
      def config_to_hash
        data = {}
        Pkg::Params::BUILD_PARAMS.each do |param|
          data.store(param, self.instance_variable_get("@#{param}"))
        end
        data.store(:platform_data, platform_data)
        data
      end

      ##
      # Write all build parameters to a yaml file, either one specified or in a
      # temporary location. Print the path to the file and return it as a
      # string. Accept an argument for the write target file. If not specified,
      # the name of the params file is the current git commit sha or tag.
      #
      def config_to_yaml(target = nil)
        file = "#{self.ref}.yaml"
        target = target.nil? ? File.join(Pkg::Util::File.mktemp, "#{self.ref}.yaml") : File.join(target, file)
        Pkg::Util::File.file_writable?(File.dirname(target), :required => true)
        File.open(target, 'w') do |f|
          f.puts self.config_to_hash.to_yaml
        end
        puts target
        target
      end

      ##
      # Print the names and values of all the params known to the build object
      #
      def print_config
        self.config_to_hash.each { |k, v| puts "#{k}: #{v}" }
      end

      ##
      # Return the names of all of the cows for the project, taking off the
      # base prefix, the architecture, and the .cow suffix. This is helpful in
      # the debian changelog.
      #
      def cow_list
        self.cows.split(' ').map do
          |cow| cow.split('-')[1]
        end.uniq.join(' ')
      end

      def default_project_root
        # Assume that either PROJECT_ROOT has been set, or we're running from the
        # project root
        #
        ENV['PROJECT_ROOT'] || Dir.pwd
      end

      def default_packaging_root
        # Assume that PACKAGING_ROOT has been set, or set the PACKAGING_ROOT to
        # one directory above the LIBDIR
        #
        defined?(PACKAGING_ROOT) ? File.expand_path(PACKAGING_ROOT) : File.expand_path(File.join(LIBDIR, ".."))
      end

      def load_default_configs
        got_config = false
        default_project_data = { :path => File.join(@project_root, "ext", "project_data.yaml"), :required => false }
        default_build_defaults = { :path => File.join(@project_root, "ext", "build_defaults.yaml"), :required => true }

        [default_project_data, default_build_defaults].each do |config|
          if File.readable? config[:path]
            self.config_from_yaml(config[:path])
            got_config = true if config[:required]
          else
            puts "Skipping load of expected default config #{config[:path]}, cannot read file."
          end
        end

        if got_config
          self.config
        else
          # Since the default configuration files are not readable, most
          # likely not present, at this point we assume the project_root
          # isn't what we hoped it would be, and unset it.
          @project_root = nil
        end
      end

      #   Set all aspects of how the package will be versioned. Versioning
      #   relies exclusively on the git describe of the project, which will
      #   fail if either Pkg::Config.project_root is nil, isn't in a git repo,
      #   or is in a git repo, but there are no tags in the repo, in which case
      #   git-describe will fail.
      #
      #   It probably seems odd to load packaging-specific version
      #   determinations, such as rpmversion here, at the top-level, and it is.
      #   The reason for this that the creation of the most basic package
      #   composition, the tarball, includes the generation of many different
      #   packaging-specific files from templates in the source, and if faced
      #   with loading rpmversion in the Tar object vs rpmversion in the
      #   Config, I opt for the latter. It's basically a lose-lose, since it
      #   really belongs in the Rpm object.

      def load_versioning
        if @project_root and Pkg::Util::Git.describe
          @ref         = Pkg::Util::Git.sha_or_tag
          @short_ref   = Pkg::Util::Git.sha_or_tag(7)
          @version     = Pkg::Util::Version.dash_version
          @gemversion  = Pkg::Util::Version.dot_version
          @debversion  = Pkg::Util::Version.debversion
          @origversion = Pkg::Util::Version.origversion
          @rpmversion  = Pkg::Util::Version.rpmversion
          @rpmrelease  = Pkg::Util::Version.rpmrelease
        else
          puts "Skipping determination of version via git describe, Pkg::Config.project_root is not set to the path of a tagged git repo."
        end
      end

      ##
      #   Since we're dealing with rake, much of the parameter override support
      #   is via environment variables passed on the command line to a rake task.
      #   These override any existing values of Pkg::Config class instance
      #   variables
      #
      def load_envvars
        Pkg::Params::ENV_VARS.each do |v|
          if var = ENV[v[:envvar].to_s]
            case v[:type]
            when :bool
              self.instance_variable_set("@#{v[:var]}", Pkg::Util.boolean_value(var))
            when :array
              self.instance_variable_set("@#{v[:var]}", string_to_array(var))
            else
              self.instance_variable_set("@#{v[:var]}", var)
            end
          end
        end
      end

      ##
      #   We supply several values by default, if they haven't been specified
      #   already by config or environment variable. This includes the project
      #   root as the default project root, which is relative to the
      #   packaging path
      #
      def load_defaults
        @project_root   ||= default_project_root
        @packaging_root ||= default_packaging_root

        Pkg::Params::DEFAULTS.each do |v|
          unless self.instance_variable_get("@#{v[:var]}")
            self.instance_variable_set("@#{v[:var]}", v[:val])
          end
        end
      end

      ##
      #
      #   Several workflows rely on being able to supply an optional yaml
      #   parameters file that overrides all set values with its data. This has
      #   always been supplied as an environment variable, "PARAMS_FILE." To
      #   honor this, we have a method in config to override values as
      #   expected. There is, however, a twist - it is absolutely essential
      #   that the overrides do not override the project_root or packaging_root
      #   settings, because this is environment-specific, and any value in a
      #   params file is going to be wrong. Thus, if we have a project root or
      #   packaging root before we begin overriding, we save it and restore it
      #   after overrides.
      #
      def load_overrides
        if ENV['PARAMS_FILE'] && ENV['PARAMS_FILE'] != ''
          if File.readable?(ENV['PARAMS_FILE'])
            project_root = self.instance_variable_get("@project_root")
            packaging_root = self.instance_variable_get("@packaging_root")
            self.config_from_yaml(ENV['PARAMS_FILE'])
            self.instance_variable_set("@project_root", project_root) if project_root
            self.instance_variable_set("@packaging_root", packaging_root) if packaging_root
          else
            fail "PARAMS_FILE was set, but not to the path to a readable file."
          end
        end
      end

      ##
      #   We also have renamed various variables as part of deprecations, and
      #   if any of these are still in use, we want to assign the values to the
      #   new variables. However, we skip this if they target variable is already
      #   populated, to avoid overwriting in the case that the user has started
      #   by populating the new variable name but left the old crufty one behind.
      #
      def issue_reassignments
        Pkg::Params::REASSIGNMENTS.each do |v|
          oldval = self.instance_variable_get("@#{v[:oldvar]}")
          newval = self.instance_variable_get("@#{v[:newvar]}")
          if newval.nil? && oldval
            self.instance_variable_set("@#{v[:newvar]}", oldval)
          end
        end
      end

      ##
      #   Quite a few variables we also want to issue custom warnings about.
      #   These are they.
      #
      def issue_deprecations
        Pkg::Params::DEPRECATIONS.each do |v|
          if self.instance_variable_get("@#{v[:var]}")
            warn v[:message]
          end
        end
      end

      ##
      #   Ask for validation of BUILD_PARAMS
      #
      #   Issued as warnings initially but the intent is to turn this into
      #   a failure.
      #
      def perform_validations
        error_count = 0
        Pkg::Params::VALIDATIONS.each do |v|
          variable_name = v[:var]
          variable_value = self.instance_variable_get("@#{v[:var]}")
          validations = v[:validations]
          validations.each do |validation|
            unless Pkg::ConfigValidations.send(validation, variable_value)
              warn "Warning: variable \"#{variable_name}\" failed validation \"#{validation}\""
              error_count += 1
            end
          end
        end

        if error_count != 0
          warn "Warning: #{error_count} validation failure(s)."
        end
      end

      def string_to_array(str)
        delimiters = /[,\s;]/
        return str if str.respond_to?('each')
        str.split(delimiters).reject { |s| s.empty? }.map { |s| s.strip }
      end

      # This method is duplicated from enterprise-dist so we can access it here.
      def cow_to_codename_arch(cow)
        /^base-(.*)-(.*)\.cow$/.match(cow).captures
      end

      # This method is duplicated from enterprise-dist so we can access it here.
      def mock_to_dist_version_arch(mock)
        # We care about matching against two patterns here:
        # pupent-3.4-el5-i386 <= old style with PE_VER baked into the mock name
        # pupent-el5-i386     <= new style derived from a template
        mock.match(/pupent(-\d\.\d)?-([a-z]*)(\d*)-([^-]*)/)[2..4]
      end

      def deb_build_targets
        if self.vanagon_project
          fail "ERROR: Could not find any deb targets. Try adding `deb_targets` to your build_defaults.yaml. If you don't want to build any debs, set this to an empty string." unless self.deb_targets
          self.deb_targets.split(' ')
        else
          fail "ERROR: Could not find any deb targets. Try adding `cows` to your build_defaults.yaml. If you don't want to build any debs, set this to an empty string." unless self.cows
          self.cows.split(' ').map do |cow|
            codename, arch = self.cow_to_codename_arch(cow)
            "#{codename}-#{arch}"
          end
        end
      end

      def rpm_build_targets
        if self.vanagon_project
          fail "ERROR: Could not find any rpm targets. Try adding `rpm_targets` to your build_defaults.yaml. If you don't want to build any rpms, set this to an empty string." unless self.rpm_targets
          self.rpm_targets.split(' ')
        else
          fail "ERROR: Could not find any rpm targets. Try adding `final_mocks` to your build_defaults.yaml. If you don't want to build any rpms, set this to an empty string." unless self.final_mocks
          self.final_mocks.split(' ').map do |mock|
            platform, version, arch = self.mock_to_dist_version_arch(mock)
            "#{platform}-#{version}-#{arch}"
          end
        end
      end

      def yum_target_path(feature_branch = false)
        target_path = "#{Pkg::Config.yum_repo_path}/#{Pkg::Config.pe_version}"
        # Target path is different for feature (PEZ) or release branches
        if feature_branch || Pkg::Config.pe_feature_branch
          return "#{target_path}/feature/repos/"
        elsif Pkg::Config.pe_release_branch
          return "#{target_path}/release/repos/"
        else
          return "#{target_path}/repos/"
        end
      end

      def apt_target_path(feature_branch = false)
        target_path = "#{Pkg::Config.apt_repo_path}/#{Pkg::Config.pe_version}"
        # Target path is different for feature (PEZ) or release branches
        if feature_branch || Pkg::Config.pe_feature_branch
          return "#{target_path}/feature/repos/"
        elsif Pkg::Config.pe_release_branch
          return "#{target_path}/release/repos/"
        else
          return "#{target_path}/repos/"
        end
      end
    end
  end
end
