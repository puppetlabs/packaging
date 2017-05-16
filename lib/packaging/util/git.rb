# Utility methods for handling git
require "fileutils"

module Pkg::Util::Git
  class << self

    GIT = Pkg::Util::Tool::GIT

    def commit_file(file, message = "changes")
      fail unless Pkg::Util::Version.is_git_repo?
      puts "Commiting changes:"
      puts
      diff, _, _ = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} diff HEAD #{file}")
      puts diff
      stdout, _, _ = Pkg::Util::Execution.capture3(%Q(#{Pkg::Util::Tool::GIT} commit #{file} -m "Commit #{message} in #{file}" &> #{Pkg::Util::OS::DEVNULL}))
      stdout
    end

    def tag(version)
      fail unless Pkg::Util::Version.is_git_repo?
      stdout, _, _ = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} tag -s -u #{Pkg::Config.gpg_key} -m '#{version}' #{version}")
      stdout
    end

    # Check if we are currently working on a tagged commit.
    def tagged?
      return git_ref_type = "tag"
    end

    # Reports if a ref and it's corresponding git repo points to
    # a git tag.
    #
    # @param url [string] url of repo grabbed from json file
    # @param ref [string] ref grabbed from json file
    def remote_tagged?(url, ref)
      reference = Pkg::Util::Git_tag.new(url, ref)
      reference.tag?
    end


    def bundle(treeish, appendix = Pkg::Util.rand_string, temp = Pkg::Util::File.mktemp)
      fail unless Pkg::Util::Version.is_git_repo?
      Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} bundle create #{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix} #{treeish} --tags")
      Dir.chdir(temp) do
        Pkg::Util::Execution.capture3("#{Pkg::Util::Tool.find_tool('tar')} -czf #{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}.tar.gz #{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}")
        FileUtils.rm_rf("#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}")
      end
      "#{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}.tar.gz"
    end

    def pull(remote, branch)
      fail unless Pkg::Util::Version.is_git_repo?
      stdout, _, _ = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} pull #{remote} #{branch}")
      stdout
    end

    def checkout(ref)
      Pkg::Util.in_project_root do
        _, _, ret = Pkg::Util::Execution.capture3("#{GIT} reset --hard ; #{GIT} checkout #{ref}")
        Pkg::Util::Execution.success?(ret) or fail "Could not checkout #{ref} git branch to build package from...exiting"
      end
    end

    def git_describe
      Pkg::Util.in_project_root do
        stdout, _, ret = Pkg::Util::Execution.capture3("#{GIT} describe")
        if Pkg::Util::Execution.success?(ret)
          stdout.strip
        else
          false
        end
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
        _, _, ret = Pkg::Util::Execution.capture3("#{GIT} rev-parse --git-dir")
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
        raw, _, ret = Pkg::Util::Execution.capture3("#{GIT} describe --tags --dirty")
        Pkg::Util::Execution.success?(ret) ? raw : nil
      end
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

  end
end
