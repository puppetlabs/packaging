# Module for signing all packages to places

module Pkg::Util::Repo
  class << self

    # Create yum repositories of built RPM packages for this SHA on the distribution server
    def rpm_repos
      Pkg::Util::File.fetch
      Pkg::Rpm::Repo.create_remote_repos
    end

    # Create apt repositories of build DEB packages for this SHA on the distributions server
    def deb_repos
      Pkg::Util::File.fetch
      Pkg::Deb::Repo.create_repos
    end
  end
end