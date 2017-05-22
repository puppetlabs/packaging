require 'fileutils'

# Utility methods for handling git
module Pkg::Util::Git
  class << self
    # Git utility to create a new git commit
    def commit_file(file, message = 'changes')
      fail_unless_repo
      puts 'Commiting changes:'
      puts
      diff, = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} diff HEAD #{file}")
      puts diff
      stdout, = Pkg::Util::Execution.capture3(%(#{Pkg::Util::Tool::GIT} commit #{file} -m "Commit #{message} in #{file}" &> #{Pkg::Util::OS::DEVNULL}))
      stdout
    end

    # Git utility to create a new git tag
    def tag(version)
      fail_unless_repo
      stdout, = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} tag -s -u #{Pkg::Config.gpg_key} -m '#{version}' #{version}")
      stdout
    end

    # Git utility to create a new git bundle
    # rubocop:disable Metrics/AbcSize
    def bundle(treeish, appendix = Pkg::Util.rand_string, temp = Pkg::Util::File.mktemp)
      fail_unless_repo
      Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} bundle create #{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix} #{treeish} --tags")
      Dir.chdir(temp) do
        Pkg::Util::Execution.capture3("#{Pkg::Util::Tool.find_tool('tar')} -czf #{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}.tar.gz #{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}")
        FileUtils.rm_rf("#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}")
      end
      "#{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}.tar.gz"
    end

    def pull(remote, branch)
      fail_unless_repo
      stdout, = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} pull #{remote} #{branch}")
      stdout
    end

    # Check if we are currently working on a tagged commit.
    def tagged?
      ref_type == 'tag'
    end

    # Reports if a ref and its corresponding git repo points to
    # a git tag.
    #
    # @param url [string] url of repo grabbed from json file
    # @param ref [string] ref grabbed from json file
    def remote_tagged?(url, ref)
      reference = Pkg::Util::Git_tag.new(url, ref)
      reference.tag?
    end

    # Checks out a specified ref. The ref must exist in the current repo.
    # This also removes any uncommitted changes
    def checkout(ref)
      Pkg::Util.in_project_root do
        _, _, ret = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} reset --hard ; #{Pkg::Util::Tool::GIT} checkout #{ref}")
        Pkg::Util::Execution.success?(ret) || raise("Could not checkout #{ref} git branch to build package from...exiting")
      end
    end

    # Returns the value of `git describe`. If this is not a git repo or
    # `git describe` fails because there is no tag, this will return false
    def describe
      Pkg::Util.in_project_root do
        stdout, _, ret = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} describe --tags --dirty")
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
    def sha(length = 40)
      Pkg::Util.in_project_root do
        stdout, = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} rev-parse --short=#{length} HEAD")
        stdout.strip
      end
    end

    # Return the ref type of HEAD on the current branch
    def ref_type
      Pkg::Util.in_project_root do
        stdout, = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} cat-file -t #{describe}")
        stdout.strip
      end
    end

    # If HEAD is a tag, return the tag. Otherwise return the sha of HEAD.
    def sha_or_tag(length = 40)
      if ref_type == 'tag'
        describe
      else
        sha(length)
      end
    end

    # Return true if we're in a git repo, otherwise false
    def repo?
      Pkg::Util.in_project_root do
        _, _, ret = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} rev-parse --git-dir")
        Pkg::Util::Execution.success?(ret)
      end
    end

    # rubocop:disable Style/GuardClause
    def fail_unless_repo
      unless repo?
        raise "Pkg::Config.project_root (#{Pkg::Config.project_root}) is not \
          a valid git repository"
      end
    end

    # Return the basename of the project repo
    def project_name
      Pkg::Util.in_project_root do
        stdout, = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} config --get remote.origin.url")
        stdout.split('/')[-1].chomp('.git').chomp
      end
    end

    # Return the name of the current branch
    def branch_name
      Pkg::Util.in_project_root do
        stdout, = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} rev-parse --abbrev-ref HEAD")
        stdout.strip
      end
    end

    def source_dirty?
      describe.include?('dirty')
    end

    def fail_on_dirty_source
      if source_dirty?
        raise "The source tree is dirty, e.g. there are uncommited changes. \
         Please commit/discard changes and try again."
      end
    end

    ##########################################################################
    # DEPRECATED METHODS
    #
    def git_commit_file(file, message = "changes")
      Pkg::Util.deprecate('Pkg::Util::Git.git_commit_file', 'Pkg::Util::Git.commit_file')
      Pkg::Util::Git.commit_file(file, message)
    end

    def git_tag(version)
      Pkg::Util.deprecate('Pkg::Util::Git.git_tag', 'Pkg::Util::Git.tag')
      Pkg::Util::Git.tag(version)
    end

    def git_bundle(treeish, appendix = Pkg::Util.rand_string, temp = Pkg::Util::File.mktemp)
      Pkg::Util.deprecate('Pkg::Util::Git.git_bundle', 'Pkg::Util::Git.bundle')
      Pkg::Util::Git.bundle(treeish, appendix, temp)
    end

    def git_pull(remote, branch)
      Pkg::Util.deprecate('Pkg::Util::Git.git_pull', 'Pkg::Util::Git.pull')
      Pkg::Util::Git.pull(remote, branch)
    end
  end
end
