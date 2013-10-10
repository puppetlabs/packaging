# Utility methods used for versioning projects for various kinds of packaging

module Pkg::Util
  class << self
    def git_co(ref)
      in_project_root do
        %x{#{GIT} reset --hard ; #{GIT} checkout #{ref}}
        $?.success? or fail "Could not checkout #{ref} git branch to build package from...exiting"
      end
    end

    def git_tagged?
      in_project_root do
        %x{#{GIT} describe >/dev/null 2>&1}
        $?.success?
      end
    end

    def git_describe
      in_project_root do
        %x{#{GIT} describe}.strip
      end
    end

    # return the sha of HEAD on the current branch
    def git_sha
      in_project_root do
        %x{#{GIT} rev-parse HEAD}.strip
      end
    end

    # Return the ref type of HEAD on the current branch
    def git_ref_type
      in_project_root do
        %x{#{GIT} cat-file -t #{git_describe}}.strip
      end
    end

    # If HEAD is a tag, return the tag. Otherwise return the sha of HEAD.
    def git_sha_or_tag
      if git_ref_type == "tag"
        git_describe
      else
        git_sha
      end
    end

    # Return true if we're in a git repo, otherwise false
    def is_git_repo
      in_project_root do
        %x{#{GIT} rev-parse --git-dir > /dev/null 2>&1}
        $?.success?
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
      if info[1].to_s.match('^[\d]+')
        version_string = info.values_at(0,1,3).compact
      else
        version_string = info.values_at(0,1,2,4).compact
      end
      version_string
    end

    # This is a stub to ease testing...
    def run_git_describe_internal
      in_project_root do
        raw = %x{#{GIT} describe --tags --dirty 2>/dev/null}
        $?.success? ? raw : nil
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
      uname = find_tool('uname', :required => true)
      %x{#{uname} -r}.chomp
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
      else
        ver = dash.gsub('-','.') + "-#{Pkg::Config.release}"
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

    # Determines if this package is an rc package via the version
    # returned by get_dash_version method.
    # Assumes version strings in the formats:
    # final:
    # '0.7.0'
    # '0.7.0-63'
    # '0.7.0-63-dirty'
    # rc:
    # '0.7.0rc1 (we don't actually use this format anymore, but once did)
    # '0.7.0-rc1'
    # '0.7.0-rc1-63'
    # '0.7.0-rc1-63-dirty'
    def is_rc?
      return TRUE if get_dash_version =~ /^\d+\.\d+\.\d+-*rc\d+/
      FALSE
    end
  end
end
