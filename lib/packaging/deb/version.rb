module Pkg::Deb::Version
  class << self
    attr_reader :debversion, :origversion

    def debversion
      Pkg::Util::Version.get_base_pkg_version.join('-') << "#{Pkg::Config.packager}1"
    end

    def origversion
      debversion.split('-')[0]
    end
  end
end
