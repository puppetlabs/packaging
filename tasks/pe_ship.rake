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
        if File.directory?("pkg/pe/deb")
          cd "pkg/pe/deb" do
            Dir["**/*.deb"].each do |deb|
              rsync_to(deb, @build.apt_host, "#{target_path}/#{File.dirname(deb)}/")
            end
          end
        else
          warn "No packages found in 'pkg/pe/deb', skipping ship of debs."
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

          # Ship all-arch debs to same place
          unless Dir["pkg/pe/deb/#{dist}/pe-*_all.deb"].empty?
            rsync_to("pkg/pe/deb/#{dist}/pe-*_all.deb --ignore-existing", @build.apt_host, "#{base_path}/#{dist}-i386/")
            rsync_to("pkg/pe/deb/#{dist}/pe-*_all.deb --ignore-existing", @build.apt_host, "#{base_path}/#{dist}-amd64/")
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


      if @build.team == 'release'
        Rake::Task["pe:remote:apt"].invoke(target_path)
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
      task :apt, :incoming do |t, args|
        incoming_dir = args.incoming
        incoming_dir or fail "Adding packages to apt repo requires an incoming directory"
        invoke_task("pl:fetch")
        remote_ssh_cmd(@build.apt_host, "/usr/bin/repsimple add_all \
            --confdir /etc/reprepro/#{@build.pe_version} \
            --basedir #{@build.apt_repo_path}/#{@build.pe_version}/repos/debian \
            --databasedir /var/lib/reprepro/#{@build.pe_version} \
            --incomingdir #{incoming_dir}")

        puts "Cleaning up apt repo 'incoming' dir on #{@build.apt_host}"
        remote_ssh_cmd(@build.apt_host, "rm -r #{incoming_dir}")

      end
    end
  end
end
