if Pkg::Config.build_pe
  namespace :pe do
    desc "ship PE rpms to #{Pkg::Config.yum_host}"
    task :ship_rpms => "pl:fetch" do
      puts "Shipping packages to #{Pkg::Config.yum_target_path}"
      Pkg::Util::File.empty_dir?("pkg/pe/rpm") and fail "The 'pkg/pe/rpm' directory has no packages. Did you run rake pe:deb?"
      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        if Pkg::Config.pe_feature_branch
          puts "On a feature branch - overwrites alllowed"
          Pkg::Util::Net.rsync_to('pkg/pe/rpm/', Pkg::Config.yum_host, Pkg::Config.yum_target_path, extra_flags: [])
        else
          Pkg::Util::Net.rsync_to('pkg/pe/rpm/', Pkg::Config.yum_host, Pkg::Config.yum_target_path)
        end
      end
      if Pkg::Config.team == 'release'

        # If this is not a feature branch, we need to link the shipped packages into the feature repos,
        # then update their metadata as well.
        unless Pkg::Config.pe_feature_branch
          puts "Linking RPMs to feature repo"
          Pkg::Util::RakeUtils.invoke_task("pe:remote:link_shipped_rpms_to_feature_repo")
          Pkg::Util::RakeUtils.invoke_task("pe:remote:update_yum_repo")
        end
      end
    end

    desc "Ship PE debs to #{Pkg::Config.apt_host}"
    task :ship_debs => "pl:fetch" do
      Pkg::Util::File.empty_dir?("pkg/pe/deb") and fail "The 'pkg/pe/deb' directory has no packages!"
      target_path = ENV['APT_REPO']

      unless Pkg::Config.pe_feature_branch
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

          #   For aptly, we ship just the debs into an incoming dir. On the remote end,
          #   aptly will pull these debs in and add them to the repositories based on the
          #   dist, e.g. lucid, architecture notwithstanding.
          #
          #   The layout that the aptly library will expect is:
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
      if Pkg::Config.pe_feature_branch
        base_path = "#{Pkg::Config.apt_repo_path}/#{Pkg::Config.pe_version}/feature/repos"
      else
        base_path = "#{Pkg::Config.apt_repo_path}/#{Pkg::Config.pe_version}/repos"
      end

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
            Pkg::Util::Net.rsync_to("pkg/pe/deb/#{dist}/*", Pkg::Config.apt_host, "#{base_path}/#{dist}-source", extra_flags: ["--exclude '*.deb'", "--ignore-existing"])
          end

          files = Dir["pkg/pe/deb/#{dist}/*{_#{arch},all}.deb"].map { |f| "#{archive_path}/#{File.basename(f)}" }

          files += Dir["pkg/pe/deb/#{dist}/*"].select { |f| f !~ /^.*\.deb$/ }.map { |f| "#{base_path}/#{dist}-source/#{File.basename(f)}" }

          # If this is not a feature branch, we need to link the shipped packages into the feature repos
          unless Pkg::Config.pe_feature_branch
            puts "Linking DEBs to feature repo"
            Pkg::Util::RakeUtils.invoke_task("pe:remote:link_shipped_debs_to_feature_repo")
          end

          unless files.empty?
            Pkg::Util::Net.remote_set_immutable(Pkg::Config.apt_host, files)
          end
        end
      end
    end

    namespace :remote do
      desc "Update remote rpm repodata for PE on #{Pkg::Config.yum_host}"
      task :update_yum_repo => "pl:fetch" do

        # Paths to the repos.
        repo_base_path = Pkg::Config.yum_target_path

        # This entire command is going to be passed across SSH, but it's unwieldy on a
        # single line. By breaking it into a series of concatenated strings, we can maintain
        # a semblance of formatting and structure (nevermind readability).
        command  = %(for dir in #{repo_base_path}/{#{rpm_family_and_version.join(",")}}-*; do)
        command += %(  sudo createrepo --checksum=sha --checkts --update --delta-workers=0 --quiet --database --update $dir; )
        command += %(done; )
        command += %(sync)

        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.yum_host, command)
      end

      desc "Remotely add shipped packages to apt repo on #{Pkg::Config.apt_host}"
      task :apt, :incoming, :dist do |t, args|
        dist = args.dist
        incoming_dir = args.incoming
        incoming_dir or fail "Adding packages to apt repo requires an incoming directory"
        Pkg::Util::RakeUtils.invoke_task("pl:fetch")

        cmd = <<-eos
          if ! flock --wait 1200 /opt/tools/aptly/db/LOCK --command /bin/true; then
            echo "Unable to acquire aptly lock, giving up" 1>&2
            exit 1
          fi
          aptly repo add -remove-files #{Pkg::Config::pe_version}-#{dist} #{incoming_dir}/#{dist}
          if [ -d /opt/tools/aptly/public/#{Pkg::Config::pe_version}/dists/#{dist} ]; then
            aptly publish update -gpg-key=\"8BBEB79B\" #{dist} #{Pkg::Config::pe_version}
          else
            aptly publish repo -gpg-key=\"8BBEB79B\" #{Pkg::Config::pe_version}-#{dist} #{Pkg::Config::pe_version}
          fi
        eos
        stdout, stderr = Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.apt_host, cmd, true)

        output = stdout.to_s + stderr.to_s

        if output.include?("ERROR:") || output.include?("There have been errors!")
          # We shouldn't ever get here if aptly returns non-zero on failure, but just in case...
          fail "Unable to add packages to debian repo. Hopefully the output has some helpful information. Output: #{output}"
        end

        puts
        puts "Aptly output: #{output}"
        puts

        puts "Cleaning up apt repo 'incoming' dir on #{Pkg::Config.apt_host}"
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.apt_host, "rm -r #{incoming_dir}")

      end

      # Throw more tires on the fire
      desc "Remotely link shipped rpm packages into feature repo on #{Pkg::Config.yum_host}"
      task :link_shipped_rpms_to_feature_repo => "pl:fetch" do
        next if Pkg::Config.pe_feature_branch
        repo_base_path = Pkg::Config.yum_target_path
        feature_repo_path = Pkg::Config.yum_target_path(true)
        pkgs = FileList['pkg/pe/rpm/**/*.rpm'].select { |path| path.gsub!('pkg/pe/rpm/', '') }
        command  = %(for pkg in #{pkgs.join(' ')}; do)
        command += %(  sudo ln -f "#{repo_base_path}/$( dirname ${pkg} )/$( basename ${pkg} )" "#{feature_repo_path}/$( dirname ${pkg} )/" ; )
        command += %(done; )
        command += %(sync)

        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.yum_host, command)
      end
      
      desc "Remotely link shipped deb packages into feature repo on #{Pkg::Config.apt_host}"
      task :link_shipped_debs_to_feature_repo => "pl:fetch" do
        next if Pkg::Config.pe_feature_branch
        feature_base_path = "#{Pkg::Config.apt_repo_path}/#{Pkg::Config.pe_version}/feature/repos"
        base_path = "#{Pkg::Config.apt_repo_path}/#{Pkg::Config.pe_version}/repos"
        pkgs = FileList["pkg/pe/deb/**/*.deb"].select { |path| path.gsub!('pkg/pe/deb/', '') }
        command  = %(for pkg in #{pkgs.join(' ')}; do)
        command += %(  sudo ln -f "#{base_path}/$( dirname ${pkg} )/$( basename ${pkg} )" "#{feature_base_path}/$( dirname ${pkg} )/" ; )
        command += %(done; )
        command += %(sync)

        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.yum_host, command)
      end
    end
  end
end
