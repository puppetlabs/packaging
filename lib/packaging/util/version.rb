# Utility methods used for versioning projects for various kinds of packaging
require 'json'

module Pkg::Util::Version
  class << self

    GIT = Pkg::Util::Tool::GIT
    DEVNULL = Pkg::Util::OS::DEVNULL

    def git_co(ref)
      Pkg::Util.in_project_root do
        _, _, ret = Pkg::Util::Execution.capture3("#{GIT} reset --hard ; #{GIT} checkout #{ref}")
        Pkg::Util::Execution.success?(ret) or fail "Could not checkout #{ref} git branch to build package from...exiting"
      end
    end

    def git_tagged?
      Pkg::Util.in_project_root do
        _, _, ret = Pkg::Util::Execution.capture3("#{GIT} describe >#{DEVNULL} 2>&1")
        Pkg::Util::Execution.success?(ret)
      end
    end

    def git_describe
      Pkg::Util.in_project_root do
        stdout, _, _ = Pkg::Util::Execution.capture3("#{GIT} describe")
        stdout.strip
      end
    end

    # return the sha of HEAD on the current branch
    # You can specify the length you want from the sha. Default is 40, the
    # length for sha1. If you specify anything higher, it will still return 40
    # characters. Ideally, you're not going to specify anything under 7 characters,
    # but I'll leave that discretion up to you.
    def git_sha(length = 40)
      Pkg::Util.in_project_root do
        stdout, _, _ = Pkg::Util::Execution.capture3("#{GIT} rev-parse --short=#{length} HEAD")
        stdout.strip
      end
    end

    # Return the ref type of HEAD on the current branch
    def git_ref_type
      Pkg::Util.in_project_root do
        stdout, _, _ = Pkg::Util::Execution.capture3("#{GIT} cat-file -t #{git_describe}")
        stdout.strip
      end
    end

    # If HEAD is a tag, return the tag. Otherwise return the sha of HEAD.
    def git_sha_or_tag(length = 40)
      if git_ref_type == "tag"
        git_describe
      else
        git_sha(length)
      end
    end

    # Return true if we're in a git repo, otherwise false
    def is_git_repo?
      Pkg::Util.in_project_root do
        _, _, ret = Pkg::Util::Execution.capture3("#{GIT} rev-parse --git-dir > #{DEVNULL} 2>&1")
        Pkg::Util::Execution.success?(ret)
      end
    end

    alias :is_git_repo :is_git_repo?

    # Return the basename of the project repo
    def git_project_name
      Pkg::Util.in_project_root do
        stdout, _, _ = Pkg::Util::Execution.capture3("#{GIT} config --get remote.origin.url")
        stdout.split('/')[-1].chomp(".git").chomp
      end
    end

    # Return information about the current tree, using `git describe`, ready for
    # further processing.
    #
    # Returns an array of one to four elements, being:
    # * version (three dot-joined numbers, leading `v` stripped)
    # * the string 'rcX' (if the last tag was an rc release, where X is the rc number)
    # * commits (string containing integer, number of commits since that version was tagged)
    # * dirty (string 'dirty' if local changes exist in the repo)
    def git_describe_version
      return nil unless is_git_repo and raw = run_git_describe_internal
      # reprocess that into a nice set of output data
      # The elements we select potentially change if this is an rc
      # For an rc with added commits our string will be something like '0.7.0-rc1-63-g51ccc51'
      # and our return will be [0.7.0, rc1, 63, <dirty>]
      # For a final with added commits, it will look like '0.7.0-63-g51ccc51'
      # and our return will be [0.7.0, 64, <dirty>]
      info = raw.chomp.sub(/^v/, '').split('-')
      if git_ref_type == "tag"
        version_string = info.compact
      elsif info[1].to_s.match('^[\d]+')
        version_string = info.values_at(0, 1, 3).compact
      else
        version_string = info.values_at(0, 1, 2, 4).compact
      end
      version_string
    end

    # This is a stub to ease testing...
    def run_git_describe_internal
      Pkg::Util.in_project_root do
        raw, _, ret = Pkg::Util::Execution.capture3("#{GIT} describe --tags --dirty 2>#{DEVNULL}")
        Pkg::Util::Execution.success?(ret) ? raw : nil
      end
    end

    def get_dash_version
      if info = git_describe_version
        info.join('-')
      else
        get_pwd_version
      end
    end

    def uname_r
      uname = Pkg::Util::Tool.find_tool('uname', :required => true)
      stdout, _, _ = Pkg::Util::Execution.capture3("#{uname} -r")
      stdout.chomp
    end

    def get_ips_version
      if info = git_describe_version
        version, commits, dirty = info
        if commits.to_s.match('^rc[\d]+')
          commits = info[2]
          dirty   = info[3]
        end
        osrelease = uname_r
        "#{version},#{osrelease}-#{commits.to_i}#{dirty ? '-dirty' : ''}"
      else
        get_pwd_version
      end
    end

    def get_dot_version
      get_dash_version.gsub('-', '.')
    end

    def get_pwd_version
      Dir.pwd.split('.')[-1]
    end

    def get_base_pkg_version
      dash = get_dash_version
      if dash.include?("rc")
        # Grab the rc number
        rc_num = dash.match(/rc(\d+)/)[1]
        ver = dash.sub(/-?rc[0-9]+/, "-0.#{Pkg::Config.release}rc#{rc_num}").gsub(/(rc[0-9]+)-(\d+)?-?/, '\1.\2')
      elsif dash.include?("SNAPSHOT")
        # Insert -0.#{release} between the version and the SNAPSHOT string
        ver = dash.sub(/^(.*)\.(SNAPSHOT\..*)$/, "\\1-0.#{Pkg::Config.release}\\2")
      else
        ver = dash.gsub('-', '.') + "-#{Pkg::Config.release}"
      end

      ver.split('-')
    end

    def get_debversion
      get_base_pkg_version.join('-') << "#{Pkg::Config.packager}1"
    end

    def get_origversion
      Pkg::Config.debversion.split('-')[0]
    end

    def get_rpmversion
      get_base_pkg_version[0]
    end

    def get_rpmrelease
      get_base_pkg_version[1]
    end

    def source_dirty?
      git_describe_version.include?('dirty')
    end

    def fail_on_dirty_source
      if source_dirty?
        fail "
    The source tree is dirty, e.g. there are uncommited changes. Please
    commit/discard changes and try again."
      end
    end

    # Determines if this package is a final package via the
    # selected version_strategy.
    # There are currently two supported version strategies.
    #
    # This method calls down to the version strategy indicated, defaulting to the
    # rc_final strategy. The methods themselves will return false if it is a final
    # release, so their return values are collected and then inverted before being
    # returned.
    def is_final?
      ret = nil
      case Pkg::Config.version_strategy
        when "rc_final"
          ret = is_rc?
        when "odd_even"
          ret = is_odd?
        when "zero_based"
          ret = is_less_than_one?
        when nil
          ret = is_rc?
      end
      return (!ret)
    end

    # the rc_final strategy (default)
    # Assumes version strings in the formats:
    # final:
    # '0.7.0'
    # '0.7.0-63'
    # '0.7.0-63-dirty'
    # development:
    # '0.7.0rc1 (we don't actually use this format anymore, but once did)
    # '0.7.0-rc1'
    # '0.7.0-rc1-63'
    # '0.7.0-rc1-63-dirty'
    # '0.7.0.SNAPSHOT.2015.03.25T0146'
    def is_rc?
      case get_dash_version
      when /^\d+\.\d+\.\d+-*rc\d+/
        TRUE
      when /^\d+\.\d+\.\d+\.SNAPSHOT\.\d{4}\.\d{2}\.\d{2}T\d{4}/
        TRUE
      else
        FALSE
      end
    end

    # the odd_even strategy (mcollective)
    # final:
    # '0.8.0'
    # '1.8.0-63'
    # '0.8.1-63-dirty'
    # development:
    # '0.7.0'
    # '1.7.0-63'
    # '0.7.1-63-dirty'
    def is_odd?
      return TRUE if get_dash_version.match(/^\d+\.(\d+)\.\d+/)[1].to_i.odd?
      return FALSE
    end

    # the pre-1.0 strategy (node classifier)
    # final:
    # '1.8.0'
    # '1.8.0-63'
    # '1.8.1-63-dirty'
    # development:
    # '0.7.0'
    # '0.7.0-63'
    # '0.7.1-63-dirty'
    def is_less_than_one?
      return TRUE if get_dash_version.match(/^(\d+)\.\d+\.\d+/)[1].to_i.zero?
      return FALSE
    end

    # Utility method to return the dist method if this is a redhat box. We use this
    # in rpm packaging to define a dist macro, and we use it in the pl:fetch task
    # to disable ssl checking for redhat 5 because it has a certs bundle so old by
    # default that it's useless for our purposes.
    def el_version
      if File.exists?('/etc/fedora-release')
        nil
      elsif File.exists?('/etc/redhat-release')
        rpm = Pkg::Util::Tool.find_tool('rpm', :required => true)
        stdout, _, _ = Pkg::Util::Execution.capture3("#{rpm} -q --qf \"%{VERSION}\" $(#{rpm} -q --whatprovides /etc/redhat-release )")
        stdout
      end
    end

    # This is to support packages that only burn-in the version number in the
    # release artifact, rather than storing it two (or more) times in the
    # version control system.  Razor is a good example of that; see
    # https://github.com/puppetlabs/Razor/blob/master/lib/project_razor/version.rb
    # for an example of that this looks like.
    #
    # If you invoke this the version will only be modified in the temporary copy,
    # with the intent that it never change the official source tree.
    def versionbump(workdir = nil)
      version = ENV['VERSION'] || Pkg::Config.version.to_s.strip
      new_version = '"' + version + '"'

      version_file = "#{workdir ? workdir + '/' : ''}#{Pkg::Config.version_file}"

      # Read the previous version file in...
      contents = IO.read(version_file)

      # Match version files containing 'VERSION = "x.x.x"' and just x.x.x
      if version_string = contents.match(/VERSION =.*/)
        old_version = version_string.to_s.split[-1]
      else
        old_version = contents
      end

      puts "Updating #{old_version} to #{new_version} in #{version_file}"
      if contents.match("@DEVELOPMENT_VERSION@")
        contents.gsub!("@DEVELOPMENT_VERSION@", version)
      elsif contents.match('version\s*=\s*[\'"]DEVELOPMENT[\'"]')
        contents.gsub!(/version\s*=\s*['"]DEVELOPMENT['"]/, "version = '#{version}'")
      elsif contents.match("VERSION = #{old_version}")
        contents.gsub!("VERSION = #{old_version}", "VERSION = #{new_version}")
      elsif contents.match("#{Pkg::Config.project.upcase}VERSION = #{old_version}")
        contents.gsub!("#{Pkg::Config.project.upcase}VERSION = #{old_version}", "#{Pkg::Config.project.upcase}VERSION = #{new_version}")
      else
        contents.gsub!(old_version, Pkg::Config.version)
      end

      # ...and write it back on out.
      File.open(version_file, 'w') { |f| f.write contents }
    end

    # Human readable output for json tags reporting. This will load the
    # input json file and output if it "looks tagged" or not
    #
    # @param json_data [hash] json data hash containing the ref to check
    def report_json_tags(json_data)
      puts "component: " + File.basename(json_data["url"])
      puts "ref: " + json_data["ref"].to_s
      if tagged?(json_data["url"], json_data["ref"].to_s)
        tagged = "Tagged? [ Yes ]"
      else
        tagged = "Tagged? [ No  ]"
      end
      col_len = (ENV["COLUMNS"] || 70).to_i
      puts format("\n%#{col_len}s\n\n", tagged)
      puts ("*" * col_len)
    end

    # Reports if a ref and it's corresponding git repo points to
    # a git tag.
    #
    # @param url [string] url of repo grabbed from json file
    # @param ref [string] ref grabbed from json file
    def tagged?(url, ref)
      reference = Pkg::Util::Git_tag.new(url, ref)
      reference.tag?
    end

  end
end
