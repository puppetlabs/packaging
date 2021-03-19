# DEB methods used by various libraries and rake tasks

module Pkg::Deb
  require 'packaging/deb/repo'
  class << self
    def set_cow_envs(cow)
      elements = /base-(.*)-(.*)\.cow/.match(cow)
      if elements.nil?
        fail "Didn't get a matching cow, e.g. 'base-squeeze-i386'"
      end

      dist = elements[1]
      arch = elements[2]
      if Pkg::Config.build_pe
        ENV['PE_VER'] = Pkg::Config.pe_version
      end
      if Pkg::Config.deb_build_mirrors
        ENV['BUILDMIRROR'] = Pkg::Config.deb_build_mirrors.map do |mirror|
          mirror.gsub(/__DIST__/, dist)
        end.join(' | ')
      end
      ENV['DIST'] = dist
      ENV['ARCH'] = arch
      if dist =~ /cumulus/
        ENV['NETWORK_OS'] = 'cumulus'
      end
    end
  end
end
