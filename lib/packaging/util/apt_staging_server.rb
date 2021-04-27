# Utility methods for handling Apt staging server.

module Pkg::Util::AptStagingServer
  class << self
    def send_packages(local_source_directory, repo_type = 'stable')
      # ENV['REPO_NAME'] = apt_repo_name(repo_type)
      %x(apt-stage-artifacts)
      fail 'APT artifact staging failed.' unless $CHILD_STATUS.success?
    end

    def apt_repo_name(repo_type = 'stable')
      unless %w[archive nightly stable].include? repo_type
        fail "unknown repo_type: #{repo_type}"
      end

      case Pkg::Config.repo_name
      when 'puppet', 'puppet7'
        return "puppet_7_#{repo_type}"
      when 'puppet6'
        return "puppet_6_#{repo_type}"
      end
    end
  end
end
