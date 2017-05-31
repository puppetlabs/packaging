module Pkg
  ##
  #   This class is meant to encapsulate all of the data we know about a build invoked with
  #   `rake package:<build>` or `rake pl:<build>`. It can read in this data via a yaml file,
  #   have it set via accessors, and serialize it back to yaml for easy transport.
  #
  class Config
    require 'packaging/config/params.rb'
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
      #   Array of platforms and relative paths to their artifacts and
      #   repo_configs (where applicable)
      #
      def platform_data
        [{ "name" => "aix-5.3-power", "artifact" => "./puppet/aix/5.3/ppc/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.aix5.3.ppc.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-aix-5.3-ppc.repo" },
         { "name" => "aix-6.1-power", "artifact" => "./puppet/aix/6.1/ppc/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.aix6.1.ppc.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-aix-6.1-ppc.repo" },
         { "name" => "aix-7.1-power", "artifact" => "./puppet/aix/7.1/ppc/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.aix7.1.ppc.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-aix-7.1-ppc.repo" },
         { "name" => "cisco-wrlinux-5-x86_64", "artifact" => "./puppet/cisco-wrlinux/5/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.cisco_wrlinux5.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-cisco-wrlinux-5-x86_64.repo" },
         { "name" => "cisco-wrlinux-7-x86_64", "artifact" => "./puppet/cisco-wrlinux/7/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.cisco_wrlinux7.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-cisco-wrlinux-7-x86_64.repo" },
         { "name" => "cumulus-2.2-amd64", "artifact" => "./puppet/deb/cumulus/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}cumulus_amd64.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-cumulus.list" },
         { "name" => "debian-7-i386", "artifact" => "./puppet/deb/wheezy/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}wheezy_i386.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-wheezy.list" },
         { "name" => "debian-7-amd64", "artifact" => "./puppet/deb/wheezy/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}wheezy_amd64.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-wheezy.list" },
         { "name" => "debian-8-i386", "artifact" => "./puppet/deb/jessie/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}jessie_i386.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-jessie.list" },
         { "name" => "debian-8-amd64", "artifact" => "./puppet/deb/jessie/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}jessie_amd64.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-jessie.list" },
         { "name" => "el-5-i386", "artifact" => "./puppet/el/5/i386/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.el5.i386.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-el-5-i386.repo" },
         { "name" => "el-5-x86_64", "artifact" => "./puppet/el/5/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.el5.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-el-5-x86_64.repo" },
         { "name" => "el-6-i386", "artifact" => "./puppet/el/6/i386/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.el6.i386.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-el-6-i386.repo" },
         { "name" => "el-6-x86_64", "artifact" => "./puppet/el/6/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.el6.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-el-6-x86_64.repo" },
         { "name" => "el-6-s390x", "artifact" => "./puppet/el/6/s390x/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.el6.s390x.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-el-6-s390x.repo" },
         { "name" => "el-7-x86_64", "artifact" => "./puppet/el/7/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.el7.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-el-7-x86_64.repo" },
         { "name" => "el-7-s390x", "artifact" => "./puppet/el/7/s390x/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.el7.s390x.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-el-7-s390x.repo" },
         { "name" => "eos-4-i386", "artifact" => "./puppet/eos/4/i386/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.eos4.i386.swix" },
         { "name" => "fedora-24-i386", "artifact" => "./puppet/fedora/24/i386/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.fc24.i386.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-fedora-24-i386.repo" },
         { "name" => "fedora-24-x86_64", "artifact" => "./puppet/fedora/24/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.fc24.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-fedora-24-x86_64.repo" },
         { "name" => "fedora-25-i386", "artifact" => "./puppet/fedora/25/i386/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.fc25.i386.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-fedora-25-i386.repo" },
         { "name" => "fedora-25-x86_64", "artifact" => "./puppet/fedora/25/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.fc25.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-fedora-25-x86_64.repo" },
         { "name" => "huaweios-6-powerpc", "artifact" => "./puppet/deb/huaweios/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}huaweios_powerpc.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-huaweios.list" },
         { "name" => "osx-10.10-x86_64", "artifact" => "./puppet/apple/10.10/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.osx10.10.dmg" },
         { "name" => "osx-10.11-x86_64", "artifact" => "./puppet/apple/10.11/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.osx10.11.dmg" },
         { "name" => "osx-10.12-x86_64", "artifact" => "./puppet/apple/10.12/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.osx10.12.dmg" },
         { "name" => "sles-11-s390x", "artifact" => "./puppet/sles/11/s390x/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.sles11.s390x.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-sles-11-s390x.repo" },
         { "name" => "sles-11-i386", "artifact" => "./puppet/sles/11/i386/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.sles11.i386.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-sles-11-i386.repo" },
         { "name" => "sles-11-x86_64", "artifact" => "./puppet/sles/11/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.sles11.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-sles-11-x86_64.repo" },
         { "name" => "sles-12-s390x", "artifact" => "./puppet/sles/12/s390x/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.sles12.s390x.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-sles-12-s390x.repo" },
         { "name" => "sles-12-x86_64", "artifact" => "./puppet/sles/12/x86_64/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.sles12.x86_64.rpm", "repo_config" => "../repo_configs/rpm/pl-#{self.project}-#{self.ref}-sles-12-x86_64.repo" },
         { "name" => "solaris-10-i386", "artifact" => "./puppet/solaris/10/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.i386.pkg.gz" },
         { "name" => "solaris-10-sparc", "artifact" => "./puppet/solaris/10/#{self.project}-#{Pkg::Util::Version.git_describe}-#{self.release}.sparc.pkg.gz" },
         { "name" => "solaris-11-i386", "artifact" => "./puppet/solaris/11/#{self.project}@#{self.version},5.11-#{self.release}.i386.p5p" },
         { "name" => "solaris-11-sparc", "artifact" => "./puppet/solaris/11/#{self.project}@#{self.version},5.11-#{self.release}.sparc.p5p" },
         { "name" => "ubuntu-14.04-i386", "artifact" => "./puppet/deb/trusty/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}trusty_i386.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-trusty.list" },
         { "name" => "ubuntu-14.04-amd64", "artifact" => "./puppet/deb/trusty/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}trusty_amd64.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-trusty.list" },
         { "name" => "ubuntu-16.04-i386", "artifact" => "./puppet/deb/xenial/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}xenial_i386.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-xenial.list" },
         { "name" => "ubuntu-16.04-amd64", "artifact" => "./puppet/deb/xenial#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}xenial_amd64.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-xenial.list" },
         { "name" => "ubuntu-16.10-i386", "artifact" => "./puppet/deb/yakkety/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}yakkety_i386.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-yakkety.list" },
         { "name" => "ubuntu-16.10-amd64", "artifact" => "./puppet/deb/yakkety/#{self.project}_#{Pkg::Util::Version.git_describe}-#{self.release}yakkety_amd64.deb", "repo_config" => "../repo_configs/deb/pl-#{self.project}-#{self.ref}-yakkety.list" },
         { "name" => "windows-2012-x64", "artifact" => "./puppet/windows/#{self.project}-#{Pkg::Util::Version.git_describe}-x64.msi" },
         { "name" => "windows-2012-x86", "artifact" => "./puppet/windows/#{self.project}-#{Pkg::Util::Version.git_describe}-x86.msi" }]
      end

      ##
      # Manipulate platform_data above to follow the PC1 directory structure
      # for artifacts
      #
      def platform_data_pc1
        platform_data.each { |platform|
          dirs = platform["artifact"].split('/')
          dirs.delete("puppet")
          if dirs[1] == 'fedora'
            dirs[2].prepend("f")
            dirs.last.sub("fc", "fedoraf")
            platform["repo_config"].sub("fedora-", "fedora-f")
          end
          dirs.insert(3, "PC1") unless dirs[1] == 'windows'
          platform["artifact"] = dirs.join('/')
        }
      end

      ##
      # Load a yaml file and use its contents to set the values for Pkg::Config
      # class instance variables
      #
      def config_from_yaml(file)
        build_data = Pkg::Util::Serialization.load_yaml(file)
        if self.apt_repo_name == 'PC1'
          build_data[:platform_data] = platform_data_pc1
        else
          build_data[:platform_data] = platform_data
        end
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
        if self.project && self.ref && Pkg::Util::Net.check_host_ssh([self.builds_server]).empty?
          dir = "/opt/jenkins-builds/#{self.project}/#{self.ref}"
          cmd = "if [ -s \"#{dir}/artifacts\" ]; then cd #{dir}; find ./artifacts/ -mindepth 2 -type f; fi"
          artifacts, _ = Pkg::Util::Net.remote_ssh_cmd(self.builds_server, cmd, true)
          artifacts = artifacts.split("\n")
          data = {}
          Pkg::Util::Platform.platform_tags.each do |tag|
            _, _, arch = Pkg::Util::Platform.parse_platform_tag(tag)
            package_format = Pkg::Util::Platform.get_attribute(tag, :package_format)
            case package_format
            when 'deb'
              artifact = artifacts.find { |e| e.include? Pkg::Util::Platform.artifacts_path(tag) and (e.include?("all") || e.include?("#{arch}.deb")) }
              repo_config = "./repo_configs/deb/pl-#{self.project}-#{self.ref}-#{Pkg::Util::Platform.get_attribute(tag, :codename)}.list" if artifact
            when 'rpm'
              artifact = artifacts.find { |e| e.include? Pkg::Util::Platform.artifacts_path(tag) and e.include?(arch) }
              repo_config = "./repo_configs/rpm/pl-#{self.project}-#{self.ref}-#{tag}.repo" if artifact
            when 'swix', 'svr4', 'ips', 'dmg', 'msi'
              artifact = artifacts.find { |e| e.include? Pkg::Util::Platform.artifacts_path(tag) and e.include?(arch) }
            else
              fail "Not sure what to do with packages with a package format of '#{package_format}' - maybe update PLATFORM_INFO?"
            end
            data[tag] = { :artifact => artifact,
                          :repo_config => repo_config,
                        } if artifact
          end
          return data
        else
          warn "Skipping platform_data collection, but don't worry about it."
          return nil
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
        # It is really quite unsafe to assume github.com/puppetlabs/packaging has been
        # cloned into $project_root/ext/packaging even if it has _always_ been the
        # default location. We really don't have much choice as of this moment but to
        # assume this directory, or assume the user has passed in the correct one via
        # ENV['PROJECT_ROOT']. It is critical we have the correct $project_root, because
        # we get all of the package versioning from the `git-describe` of $project. If we
        # assume $project/ext/packaging, it means packaging/lib/packaging.rb is
        # three subdirectories below $project_root, e.g.,
        # $project_root/ext/packaging/lib/packaging.rb.
        #
        ENV['PROJECT_ROOT'] || File.expand_path(File.join(LIBDIR, "..", "..", ".."))
      end

      def default_packaging_root
        # It is really quite unsafe to assume github.com/puppetlabs/packaging has been
        # cloned into $project_root/ext/packaging even if it has _always_ been the
        # default location. Here we use the PACKAGING_ROOT constant defined in
        # packaging.rake if it is available, or use the parent directory of the
        # current file as the packaging_root.
        #
        defined?(PACKAGING_ROOT) ? File.expand_path(PACKAGING_ROOT) : File.expand_path(File.join(LIBDIR, ".."))
      end

      def load_default_configs
        default_project_data = File.join(@project_root, "ext", "project_data.yaml")
        default_build_defaults = File.join(@project_root, "ext", "build_defaults.yaml")

        [default_project_data, default_build_defaults].each do |config|
          if File.readable? config
            self.config_from_yaml(config)
          else
            puts "Skipping load of expected default config #{config}, cannot read file."
            #   Since the default configuration files are not readable, most
            #   likely not present, at this point we assume the project_root
            #   isn't what we hoped it would be, and unset it.
            @project_root = nil
          end
        end

        if @project_root
          self.config
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
        if @project_root and Pkg::Util::Version.git_tagged?
          @ref         = Pkg::Util::Version.git_sha_or_tag
          @short_ref   = Pkg::Util::Version.git_sha_or_tag(7)
          @version     = Pkg::Util::Version.get_dash_version
          @gemversion  = Pkg::Util::Version.get_dot_version
          @ipsversion  = Pkg::Util::Version.get_ips_version
          @debversion  = Pkg::Util::Version.get_debversion
          @origversion = Pkg::Util::Version.get_origversion
          @rpmversion  = Pkg::Util::Version.get_rpmversion
          @rpmrelease  = Pkg::Util::Version.get_rpmrelease
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
          self.deb_targets.split(' ')
        else
          self.cows.split(' ').map do |cow|
            codename, arch = self.cow_to_codename_arch(cow)
            "#{codename}-#{arch}"
          end
        end
      end

      def rpm_build_targets
        if self.vanagon_project
          self.rpm_targets.split(' ')
        else
          self.final_mocks.split(' ').map do |mock|
            platform, version, arch = self.mock_to_dist_version_arch(mock)
            "#{platform}-#{version}-#{arch}"
          end
        end
      end

      def yum_target_path(feature_branch = false)
        if feature_branch || Pkg::Config.pe_feature_branch
          return "#{Pkg::Config.yum_repo_path}/#{Pkg::Config.pe_version}/feature/repos/"
        end
        "#{Pkg::Config.yum_repo_path}/#{Pkg::Config.pe_version}/repos/"
      end
    end
  end
end
