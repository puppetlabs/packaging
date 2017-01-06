# Utility methods for handling git
require "fileutils"

module Pkg::Util::Git
  class << self
    def git_commit_file(file, message = "changes")
      fail unless Pkg::Util::Version.is_git_repo?
      puts "Commiting changes:"
      puts
      diff, _, _ = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} diff HEAD #{file}")
      puts diff
      stdout, _, _ = Pkg::Util::Execution.capture3(%Q(#{Pkg::Util::Tool::GIT} commit #{file} -m "Commit #{message} in #{file}" &> #{Pkg::Util::OS::DEVNULL}))
      stdout
    end

    def git_tag(version)
      fail unless Pkg::Util::Version.is_git_repo?
      stdout, _, _ = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} tag -s -u #{Pkg::Config.gpg_key} -m '#{version}' #{version}")
      stdout
    end

    def git_bundle(treeish, appendix = Pkg::Util.rand_string, temp = Pkg::Util::File.mktemp)
      fail unless Pkg::Util::Version.is_git_repo?
      Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} bundle create #{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix} #{treeish} --tags")
      Dir.chdir(temp) do
        Pkg::Util::Execution.capture3("#{Pkg::Util::Tool.find_tool('tar')} -czf #{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}.tar.gz #{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}")
        FileUtils.rm_rf("#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}")
      end
      "#{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}.tar.gz"
    end

    def git_pull(remote, branch)
      fail unless Pkg::Util::Version.is_git_repo?
      stdout, _, _ = Pkg::Util::Execution.capture3("#{Pkg::Util::Tool::GIT} pull #{remote} #{branch}")
      stdout
    end

  end
end


