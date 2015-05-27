if Pkg::Config.build_pe
  namespace :pe do
    desc "ship PE rpms to #{Pkg::Config.yum_host}"
    task :ship_rpms => "pl:fetch" do
      Pkg::Util::File.empty_dir?("pkg/pe/rpm") and fail "The 'pkg/pe/rpm' directory has no packages. Did you run rake pe:deb?"
      target_path = ENV['YUM_REPO'] ? ENV['YUM_REPO'] : "#{Pkg::Config.yum_repo_path}/#{Pkg::Config.pe_version}/repos/"
      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        Pkg::Util::Net.rsync_to('pkg/pe/rpm/', Pkg::Config.yum_host, target_path)
      end
      if Pkg::Config.team == 'release'
        Rake::Task["pe:remote:update_yum_repo"].invoke
      end
    end

    desc "Ship PE debs to #{Pkg::Config.apt_host}"
    task :ship_debs => "pl:fetch" do
      Pkg::Util::File.empty_dir?("pkg/pe/deb") and fail "The 'pkg/pe/deb' directory has no packages!"
      target_path = ENV['APT_REPO']

      #   If APT_REPO isn't specified as an environment variable, we use a temporary one
      #   created for this specific deb ship. This enables us to escape the conflicts
      #   introduced with simultaneous deb ships.
      #

      #   We are going to iterate over every set of packages, adding them to
      #   the repository set by set. This enables us to handle different
      #   repositories per distribution. "pkg/pe/deb/" contains directories
      #   named for every distribution, e.g. "lucid," "squeeze," etc.
      #
      Dir["pkg/pe/deb/*"].each do |dist|
        dist = File.basename(dist)
        unless target_path
          puts "Creating temporary incoming dir on #{Pkg::Config.apt_host}"
          target_path = %x(ssh -t #{Pkg::Config.apt_host} 'mktemp -d -t incoming-XXXXXX').chomp
        end

        #   For reprepro, we ship just the debs into an incoming dir. On the remote end,
        #   reprepro will pull these debs in and add them to the repositories based on the
        #   dist, e.g. lucid, architecture notwithstanding.
        #
        #   The layout that the reprepro library will expect is:
        #
        #     incoming_dir/{$dists}/*.deb
        #
        #   ex:
        #     incoming_dir|
        #                 |_lucid/*.deb
        #                 |_squeeze/*.deb
        #                 |_precise/*.deb
        #                 |_wheezy/*.deb
        #
        puts "Shipping PE debs to apt repo 'incoming' dir on #{Pkg::Config.apt_host}"
        Pkg::Util::Execution.retry_on_fail(:times => 3) do
          Dir["pkg/pe/deb/#{dist}/*.deb"].each do |deb|
            Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.apt_host, "mkdir -p '#{target_path}/#{dist}'")
            Pkg::Util::Net.rsync_to(deb, Pkg::Config.apt_host, "#{target_path}/#{dist}/#{File.basename(deb)}")
          end
        end

        if Pkg::Config.team == 'release'
          Rake::Task["pe:remote:apt"].reenable
          Rake::Task["pe:remote:apt"].invoke(target_path, dist)
        end

      end

      #   We also ship our PE artifacts to directories for archival purposes and to
      #   ease the gathering of both debs and sources when we do PE compose and ship. For
      #   this case, we ship everything to directories that mirror the legacy rpm
      #   directory format:
      #
      #     repos/$dist-{$architecture|source}
      #
      #   ex:
      #     repos|
      #          |_squeeze-i386
      #          |_squeeze-amd64
      #          |_squeeze-source
      #
      #   We also have concerns about shipped artifacts getting accidentally overwritten
      #   by newer ones. To handle this, we make everything we ship to the archive
      #   directories immutable, after rsyncing out.
      #
      base_path = "#{Pkg::Config.apt_repo_path}/#{Pkg::Config.pe_version}/repos"

      puts "Shipping all built artifacts to to archive directories on #{Pkg::Config.apt_host}"


      Pkg::Config.deb_build_targets.each do |target|
        dist, arch = target.match(/(.*)-(.*)/)[1, 2]
        unless Pkg::Util::File.empty_dir? "pkg/pe/deb/#{dist}"
          archive_path = "#{base_path}/#{dist}-#{arch}"

          # Ship arch-specific debs to correct dir, e.g. 'squeeze-i386'
          unless Dir["pkg/pe/deb/#{dist}/*_#{arch}.deb"].empty?
            Pkg::Util::Net.rsync_to("pkg/pe/deb/#{dist}/*_#{arch}.deb", Pkg::Config.apt_host, "#{archive_path}/")
          end

          # Ship all-arch debs to same dist-location, but to all known
          # architectures for this distribution.
          #
          # I am not proud of this. MM - 1/3/2014.

          unless Dir["pkg/pe/deb/#{dist}/*_all.deb"].empty?
            if dist =~ /cumulus/
              Pkg::Util::Net.rsync_to("pkg/pe/deb/#{dist}/*_all.deb", Pkg::Config.apt_host, "#{base_path}/#{dist}-powerpc/")
            else
              Pkg::Util::Net.rsync_to("pkg/pe/deb/#{dist}/*_all.deb", Pkg::Config.apt_host, "#{base_path}/#{dist}-i386/")
              Pkg::Util::Net.rsync_to("pkg/pe/deb/#{dist}/*_all.deb", Pkg::Config.apt_host, "#{base_path}/#{dist}-amd64/")
            end
          end

          unless Dir["pkg/pe/deb/#{dist}/*"].select { |i| i !~ /^.*\.deb$/ }.empty?
            # Ship source files to source dir, e.g. 'squeeze-source'
            Pkg::Util::Net.rsync_to("pkg/pe/deb/#{dist}/*", Pkg::Config.apt_host, "#{base_path}/#{dist}-source", ["--exclude '*.deb'", "--ignore-existing"])
          end

          files = Dir["pkg/pe/deb/#{dist}/*{_#{arch},all}.deb"].map { |f| "#{archive_path}/#{File.basename(f)}" }

          files += Dir["pkg/pe/deb/#{dist}/*"].select { |f| f !~ /^.*\.deb$/ }.map { |f| "#{base_path}/#{dist}-source/#{File.basename(f)}" }

          unless files.empty?
            remote_set_immutable(Pkg::Config.apt_host, files)
          end
        end
      end
    end

    namespace :remote do
      desc "Update remote rpm repodata for PE on #{Pkg::Config.yum_host}"
      task :update_yum_repo => "pl:fetch" do
        repo_base_path = File.join(Pkg::Config.yum_repo_path, Pkg::Config.pe_version, "repos")

        # This entire command is going to be passed across SSH, but it's unwieldy on a
        # single line. By breaking it into a series of concatenated strings, we can maintain
        # a semblance of formatting and structure (nevermind readability).
        command  = %(for dir in #{repo_base_path}/{#{rpm_family_and_version.join(",")}}-*; do)
        command += %(  sudo createrepo --checksum=sha --quiet --database --update $dir; )
        command += %(done; )
        command += %(sync)

        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.yum_host, command)
      end

      #   the repsimple application is a small wrapper around reprepro, the purpose of
      #   which is largely to limit the surface area and functionality of reprepro to
      #   some very basic tasks - add, remove, and add all in a directory. The add_all
      #   command expects an incoming directory option containing .deb files.
      #   Per previous comments, the incoming directory must contain subdirectories named
      #   for debian distributions.
      desc "Remotely add shipped packages to apt repo on #{Pkg::Config.apt_host}"
      task :apt, :incoming, :dist do |t, args|
        dist = args.dist
        if dist =~ /cumulus/
          reprepro_confdir = "/etc/reprepro/networking/#{Pkg::Config.pe_version}/cumulus"
          reprepro_basedir = "/opt/enterprise/networking/#{Pkg::Config.pe_version}/cumulus"
          reprepro_dbdir = "/var/lib/reprepro/networking/#{Pkg::Config.pe_version}/cumulus"
        else
          reprepro_confdir = "/etc/reprepro/#{Pkg::Config.pe_version}"
          reprepro_basedir = "#{Pkg::Config.apt_repo_path}/#{Pkg::Config.pe_version}/repos/debian"
          reprepro_dbdir = "/var/lib/reprepro/#{Pkg::Config.pe_version}"
        end

        incoming_dir = args.incoming
        incoming_dir or fail "Adding packages to apt repo requires an incoming directory"
        Pkg::Util::RakeUtils.invoke_task("pl:fetch")
        stdout, stderr = Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.apt_host, "/usr/bin/repsimple add_all \
            --confdir #{reprepro_confdir} \
            --basedir #{reprepro_basedir} \
            --databasedir #{reprepro_dbdir} \
            --incomingdir #{incoming_dir} \
            --verbose", true)

        if (stdout + stderr).include?("Skipping inclusion")
          fail "Unable to add packages to debian repo because it already contains identical files. Perhaps you are trying to ship a deb that already exists. Verify the debs are a newer version than what already exists in #{reprepro_basedir} on #{Pkg::Config.apt_host}"
        end
        puts "Cleaning up apt repo 'incoming' dir on #{Pkg::Config.apt_host}"
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.apt_host, "rm -r #{incoming_dir}")

      end
    end
  end
end
