if @build.build_pe
  namespace :pe do
    desc "ship PE rpms to #{@build.yum_host}"
    task :ship_rpms => "pl:fetch" do
      empty_dir?("pkg/pe/rpm") and fail "The 'pkg/pe/rpm' directory has no packages. Did you run rake pe:deb?"
      target_path = ENV['YUM_REPO'] ? ENV['YUM_REPO'] : "#{@build.yum_repo_path}/#{@build.pe_version}/repos/"
      retry_on_fail(:times => 3) do
        rsync_to('pkg/pe/rpm/', @build.yum_host, target_path)
      end
      if @build.team == 'release'
        Rake::Task["pe:remote:update_yum_repo"].invoke
      end
    end

    desc "Ship PE debs to #{@build.apt_host}"
    task :ship_debs => "pl:fetch" do
      empty_dir?("pkg/pe/deb") and fail "The 'pkg/pe/deb' directory has no packages!"
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
          puts "Creating temporary incoming dir on #{@build.apt_host}"
          target_path = %x{ssh -t #{@build.apt_host} 'mktemp -d -t incoming-XXXXXX'}.chomp
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
        puts "Shipping PE debs to apt repo 'incoming' dir on #{@build.apt_host}"
        retry_on_fail(:times => 3) do
          Dir["pkg/pe/deb/#{dist}/*.deb"].each do |deb|
            remote_ssh_cmd(@build.apt_host, "mkdir -p '#{target_path}/#{dist}'")
            rsync_to(deb, @build.apt_host, "#{target_path}/#{dist}/#{File.basename(deb)}")
          end
        end

        if @build.team == 'release'
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
      base_path = "#{@build.apt_repo_path}/#{@build.pe_version}/repos"

      puts "Shipping all built artifacts to to archive directories on #{@build.apt_host}"

      @build.cows.split(' ').map { |i| i.sub('.cow','') }.each do |cow|
        _base, dist, arch = cow.split('-')
        unless empty_dir? "pkg/pe/deb/#{dist}"
          archive_path = "#{base_path}/#{dist}-#{arch}"

          # Ship arch-specific debs to correct dir, e.g. 'squeeze-i386'
          unless Dir["pkg/pe/deb/#{dist}/pe-*_#{arch}.deb"].empty?
            rsync_to("pkg/pe/deb/#{dist}/pe-*_#{arch}.deb --ignore-existing", @build.apt_host, "#{archive_path}/" )
          end

          # Ship all-arch debs to same dist-location, but to all known
          # architectures for this distribution.
          #
          # I am not proud of this. MM - 1/3/2014.

          unless Dir["pkg/pe/deb/#{dist}/pe-*_all.deb"].empty?
            if dist =~ /cumulus/
              rsync_to("pkg/pe/deb/#{dist}/pe-*_all.deb --ignore-existing", @build.apt_host, "#{base_path}/#{dist}-powerpc/")
            else
              rsync_to("pkg/pe/deb/#{dist}/pe-*_all.deb --ignore-existing", @build.apt_host, "#{base_path}/#{dist}-i386/")
              rsync_to("pkg/pe/deb/#{dist}/pe-*_all.deb --ignore-existing", @build.apt_host, "#{base_path}/#{dist}-amd64/")
            end
          end

          unless Dir["pkg/pe/deb/#{dist}/pe-*"].select { |i| i !~ /^.*\.deb$/ }.empty?
            # Ship source files to source dir, e.g. 'squeeze-source'
            rsync_to("pkg/pe/deb/#{dist}/pe-* --exclude *.deb --ignore-existing", @build.apt_host, "#{base_path}/#{dist}-source")
          end

          files = Dir["pkg/pe/deb/#{dist}/pe-*{_#{arch},all}.deb"].map { |f| "#{archive_path}/#{File.basename(f)}" }

          files += Dir["pkg/pe/deb/#{dist}/pe-*"].select { |f| f !~ /^.*\.deb$/ }.map { |f| "#{base_path}/#{dist}-source/#{File.basename(f)}" }

          unless files.empty?
            remote_set_immutable(@build.apt_host, files)
          end
        end
      end

    end

    namespace :remote do
      desc "Update remote rpm repodata for PE on #{@build.yum_host}"
      task :update_yum_repo => "pl:fetch" do
        remote_ssh_cmd(@build.yum_host, "for dir in  $(find #{@build.apt_repo_path}/#{@build.pe_version}/repos/{sles,el}* -type d | grep -v repodata | grep -v cache | xargs)  ; do pushd $dir; sudo createrepo -q -d --update .; popd &> /dev/null ; done; sync")
      end

      #   the repsimple application is a small wrapper around reprepro, the purpose of
      #   which is largely to limit the surface area and functionality of reprepro to
      #   some very basic tasks - add, remove, and add all in a directory. The add_all
      #   command expects an incoming directory option containing .deb files.
      #   Per previous comments, the incoming directory must contain subdirectories named
      #   for debian distributions.
      desc "Remotely add shipped packages to apt repo on #{@build.apt_host}"
      task :apt, :incoming, :dist do |t, args|
        dist = args.dist
        if dist =~ /cumulus/
          reprepro_confdir = "/etc/reprepro/networking/#{@build.pe_version}/cumulus"
          reprepro_basedir = "/opt/enterprise/networking/#{@build.pe_version}/cumulus"
          reprepro_dbdir = "/var/lib/reprepro/networking/#{@build.pe_version}/cumulus"
        else
          reprepro_confdir = "/etc/reprepro/#{@build.pe_version}"
          reprepro_basedir = "#{@build.apt_repo_path}/#{@build.pe_version}/repos/debian"
          reprepro_dbdir = "/var/lib/reprepro/#{@build.pe_version}"
        end

        incoming_dir = args.incoming
        incoming_dir or fail "Adding packages to apt repo requires an incoming directory"
        invoke_task("pl:fetch")
        remote_ssh_cmd(@build.apt_host, "/usr/bin/repsimple add_all \
            --confdir #{reprepro_confdir} \
            --basedir #{reprepro_basedir} \
            --databasedir #{reprepro_dbdir} \
            --incomingdir #{incoming_dir}")

        puts "Cleaning up apt repo 'incoming' dir on #{@build.apt_host}"
        remote_ssh_cmd(@build.apt_host, "rm -r #{incoming_dir}")

      end
    end
  end
end
