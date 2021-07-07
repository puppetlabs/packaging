# Utility methods for handling Apt staging server.

require 'English'

module Pkg::Util::AptStagingServer
  class << self
    def send_packages(local_source_directory, repo_type = 'stable')
      %x(apt-stage-artifacts)
      fail 'APT artifact staging failed.' unless $CHILD_STATUS.success?
    end
  end
end
