# Utility methods for handling Apt staging server.

module Pkg::Util::AptStagingServer
  def self.send_packages(pkg_directory, apt_component = 'stable')
    %x(apt-stage-artifacts --component=#{apt_component} #{pkg_directory})
    fail 'APT artifact staging failed.' unless $CHILD_STATUS.success?
  end
end
