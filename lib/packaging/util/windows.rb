# Utility methods for handling windows

require 'fileutils'

module Pkg::Util::Windows
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

          # Dear future code spelunkers:
          # Using symlinks instead of hard links causes failures when we try
          # to set these files to be immutable. Also be wary of whether the
          # linking utility you're using expects the source path to be relative
          # to the link target or pwd.
          FileUtils.ln(package_filename, link_filename)
        end
      end
    end
  end
end
