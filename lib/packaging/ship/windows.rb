# Shipping methods for handling windows

require 'fileutils'

module Pkg::Ship::Windows
  class << self
    def add_msi_links(local_source_directory)
      {
        'windows' => ['x86', 'x64'],
        'windowsfips' => ['x64']
      }.each_pair do |platform, archs|
        packages = Dir["#{local_source_directory}/#{platform}/*"]

        archs.each do |arch|
          package_version = Pkg::Util::Git.describe.tr('-', '.')
          package_filename = File.join(
            local_source_directory, platform,
            "#{Pkg::Config.project}-#{package_version}-#{arch}.msi"
          )

          link_filename = File.join(
            local_source_directory,
            platform,
            "#{Pkg::Config.project}-#{arch}.msi"
          )

          next unless !packages.include?(link_filename) && packages.include?(package_filename)
          FileUtils.ln(package_filename, link_filename)
        end
      end
    end
  end
end
