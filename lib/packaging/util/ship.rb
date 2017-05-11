module Pkg::Util::Ship
  class << self
    def ship_pkgs(pkg_exts, staging_server, pkg_path, options = { addtl_path_to_sub: '', excludes: [], chattr: true } )
      #if pkg_exts.include?(".deb")
      #  pkg_type = 'deb'
      #  repo_name = Pkg::Deb::Repo.repo_name
      #elsif pkg_exts.include?(".rpm")
      #  pkg_type = 'rpm'
      #  repo_name = Pkg::Rpm::Repo.repo_name
      #else
      #  pkg_type = nil
      #  repo_name = ''
      #end

      local_pkgs = []
      pkg_exts.each do |ext|
        local_pkgs << Dir[ext]
      end
      local_pkgs.flatten!

      if options[:excludes]
        options[:excludes].each do |exclude|
          local_pkgs.delete_if { |p| p.match?(exclude) }
        end
      end

      if local_pkgs.empty?
        $stdout.puts "**********************************************************************"
        $stdout.puts "No packages with (#{pkg_exts.join(", ")}) extensions found staged in 'pkg'"
        $stdout.puts "**********************************************************************"
      else
        puts local_pkgs
        puts "Do you want to ship the above files to (#{staging_server})?"
        if Pkg::Util.ask_yes_or_no

          extra_flags = ['--ignore-existing', '--delay-updates']
          extra_flags << '--dry-run' if ENV['DRYRUN']

          local_pkgs.each do |pkg|

            #fail "Expecting #{pkg} to have #{repo_name} in path" unless pkg.include?(repo_name)

            Pkg::Util::Execution.retry_on_fail(:times => 3) do
              if options[:addtl_path_to_sub]
                path = "pkg#{options[:addtl_path_to_sub]}"
              else
                path = "pkg"
              end
              remote_pkg = pkg.gsub(path, pkg_path)
              remote_basepath = File.dirname(remote_pkg)
              Pkg::Util::Net.remote_ssh_cmd(staging_server, "mkdir -p #{remote_basepath}")
              Pkg::Util::Net.rsync_to(
                pkg,
                staging_server,
                remote_basepath,
                extra_flags: extra_flags
              )

              Pkg::Util::Net.remote_set_ownership(staging_server, 'root', 'release', [remote_pkg])
              Pkg::Util::Net.remote_set_permissions(staging_server, '0664', [remote_pkg])
              Pkg::Util::Net.remote_set_immutable(staging_server, [remote_pkg]) if options[:chattr]
            end
          end
        end
      end
    end
  end
end

