# Utilities for working with rpm repos
require 'fileutils'
require 'find'

module Pkg::Rpm::Repo
  class << self
    def base_url
      "http://#{Pkg::Config.builds_server}/#{Pkg::Config.project}/#{Pkg::Config.ref}"
    end

    def ship_repo_configs(target = "repo_configs")
      if Pkg::Util::File.empty_dir?("pkg/#{target}/rpm")
        warn "No repo configs have been generated! Try pl:rpm_repo_configs."
        return
      end

      invoke_task("pl:fetch")
      repo_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/#{target}/rpm"
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir -p #{repo_dir}")
      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        Pkg::Util::Net.rsync_to("pkg/#{target}/rpm/", Pkg::Config.distribution_server, repo_dir)
      end
    end

    def repo_creation_command(createrepo)
      cmd = 'for repodir in $(find ./ -name "*.rpm" | xargs -I {} dirname {}) ; do '
      cmd << "[ -d ${repodir} ] || continue; "
      cmd << "pushd ${repodir} && #{createrepo} --checksum=sha --checkts --update --delta-workers=0 --database . ; popd ; "
      cmd << "done "
    end

    # @deprecated this command will die a painful death when we are
    #   able to sit down with Operations and refactor our distribution infra.
    #   At a minimum, it should be refactored alongside its Debian counterpart
    #   into something modestly more generic.
    #   - Ryan McKern 11/2015
    #
    # @param origin_path [String] path for RPM repos on local filesystem
    # @param destination_path [String] path for RPM repos on remote filesystem
    # @param destination [String] remote host to send rsynced content to. If
    #        nil will copy locally
    # @param dryrun [Boolean] whether or not to use '--dry-run'
    #
    # @return [String] an rsync command that can be executed on a remote host
    #   to copy local content from that host to a remote node.
    def repo_deployment_command(origin_path, destination_path, destination, dryrun = false)
      path = Pathname.new(origin_path)
      dest_path = Pathname.new(destination_path)

      # You may think "rsync doesn't actually remove the sticky bit, let's
      # remove the Dugo-s from the chmod". However, that will make your rsyncs
      # fail due to permission errors.
      options = %w(
        rsync
        --recursive
        --links
        --hard-links
        --update
        --human-readable
        --itemize-changes
        --progress
        --verbose
        --super
        --delay-updates
        --omit-dir-times
        --no-perms
        --no-owner
        --no-group
      )

      options << '--dry-run' if dryrun
      options << path

      if destination
        options << "#{destination}:#{dest_path.parent}"
      else
        options << "#{dest_path.parent}"
      end

      options.join("\s")
    end

    def create_repos(directory = "repos")
      Dir.chdir(directory) do
        createrepo = Pkg::Util::Tool.check_tool('createrepo')
        stdout, _, _ = Pkg::Util::Execution.capture3("bash -c '#{repo_creation_command(createrepo)}'")
        stdout
      end
    end

    def sign_repos(directory)
      files_to_sign = Find.find(directory).select { |file| file.match(/repomd.xml$/) }
      files_to_sign.each do |file|
        Pkg::Util::Gpg.sign_file(file)
      end
    end

    def retrieve_repo_configs(target = "repo_configs")
      wget = Pkg::Util::Tool.check_tool("wget")
      FileUtils.mkdir_p("pkg/#{target}")
      config_url = "#{base_url}/#{target}/rpm/"
      begin
        stdout, _, _ = Pkg::Util::Execution.capture3("#{wget} -r -np -nH --cut-dirs 3 -P pkg/#{target} --reject 'index*' #{config_url}")
        stdout
      rescue => e
        fail "Couldn't retrieve rpm yum repo configs.\n#{e}"
      end
    end

    # Generate yum configuration files that point to the repositories created
    # on the distribution server with packages created from the current source
    # repo commit. There is one for each dist/version that is packaged (e.g.
    # el5, el6, etc). Files are created in pkg/repo_configs/rpm and are named
    # pl-$project-$sha.conf, and can be placed in /etc/yum.repos.d to enable
    # clients to install these packages.
    #
    def generate_repo_configs(source = "repos", target = "repo_configs", signed = false)
      # We have a hard requirement on wget because of all the download magicks
      # we have to do
      #
      wget = Pkg::Util::Tool.check_tool("wget")

      # This is the standard path to all build artifacts on the distribution
      # server for this commit
      #
      repo_base = "#{base_url}/#{source}/"

      # First check if the artifacts directory exists
      #

      # We have to do two checks here - first that there are directories with
      # repodata folders in them, and second that those same directories also
      # contain rpms
      #
      stdout, _, _ = Pkg::Util::Execution.capture3("#{wget} --spider -r -l 5 --no-parent #{repo_base} 2>&1")
      stdout = stdout.split.uniq.reject { |x| x =~ /\?|index/ }.select { |x| x =~ /http:.*repodata\/$/ }

      # RPMs will always exist at the same directory level as the repodata
      # folder, which means if we go up a level we should find rpms
      #
      yum_repos = []
      stdout.map { |x| x.chomp('repodata/') }.each do |url|
        output, _, _ = Pkg::Util::Execution.capture3("#{wget} --spider -r -l 1 --no-parent #{url} 2>&1")
        unless output.split.uniq.reject { |x| x =~ /\?|index/ }.select { |x| x =~ /http:.*\.rpm$/ }.empty?
          yum_repos << url
        end
      end

      if yum_repos.empty?
        warn "No rpm repos were found to generate configs from!"
        return
      end

      FileUtils.mkdir_p(File.join("pkg", target, "rpm"))

      # Parse the rpm configs file to generate repository configs. Each line in
      # the rpm_configs file corresponds with a repo directory on the
      # distribution server.
      #
      yum_repos.each do |url|
        # We ship a base 'srpm' that gets turned into a repo, but we want to
        # ignore this one because its an extra
        next if url == "#{repo_base}srpm/"

        dist, version, _subdir, arch = url.split('/')[-4..-1]

        # Create an array of lines that will become our yum config
        #
        config = ["[pl-#{Pkg::Config.project}-#{Pkg::Config.ref}]"]
        config << ["name=PL Repo for #{Pkg::Config.project} at commit #{Pkg::Config.ref}"]
        config << ["baseurl=#{url}"]
        config << ["enabled=1"]
        if signed
          config << ["gpgcheck=1"]
          config << ["gpgkey=http://#{Pkg::Config.builds_server}/#{Pkg::Config.gpg_key}"]
        else
          config << ["gpgcheck=0"]
        end

        # Write the new config to a file under our repo configs dir
        #
        config_file = File.join("pkg", target, "rpm", "pl-#{Pkg::Config.project}-#{Pkg::Config.ref}-#{dist}-#{version}-#{arch}.repo")
        File.open(config_file, 'w') { |f| f.puts config }
      end
      puts "Wrote yum configuration files for #{Pkg::Config.project} at #{Pkg::Config.ref} to pkg/#{target}/rpm"
    end

    def create_repos_from_artifacts
      # Formulate our command string, which will just find directories with rpms
      # and create and update repositories.
      #
      artifact_directory = File.join(Pkg::Config.jenkins_repo_path, Pkg::Config.project, Pkg::Config.ref)

      ##
      # Test that the artifacts directory exists on the distribution server.
      # This will give us some more helpful output.
      #
      cmd = 'echo "Checking for build artifacts. Will exit if not found." ; '
      cmd << "[ -d #{artifact_directory}/artifacts ] || exit 1 ; "

      ##
      # Enter the directory containing the build artifacts and create repos.
      #
      cmd << "pushd #{artifact_directory} ; "
      cmd << 'echo "Checking for running repo creation. Will wait if detected." ; '
      cmd << "while [ -f .lock ] ; do sleep 1 ; echo -n '.' ; done ; "
      cmd << 'echo "Setting lock" ; '
      cmd << "touch .lock ; "
      cmd << "rsync -avxl artifacts/ repos/ ; pushd repos ; "
      cmd << "createrepo=$(which createrepo) ; "
      cmd << 'for repodir in $(find ./ -name "*.rpm" | xargs -I {} dirname {}) ; do '
      cmd << "[ -d ${repodir} ] || continue; "
      cmd << "pushd ${repodir} && ${createrepo} --checksum=sha --checkts --update --delta-workers=0 --database . ; popd ; "
      cmd << "done ; popd "

      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, cmd)
      # Now that we've created our repositories, we can create the configs for
      # them
      Pkg::Rpm::Repo.generate_repo_configs

      # And once they're created, we can ship them
      Pkg::Rpm::Repo.ship_repo_configs
    ensure
      # Always remove the lock file, even if we've failed
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "rm -f #{artifact_directory}/.lock")
    end

    # @deprecated this command is exactly as awful as you think it is.
    #   -- Ryan McKern 12/2015
    #
    # @param yum_path [String] path for rpm repos on local and remote filesystem
    # @param origin_server [String] remote host to start the  rsync from
    # @param destination_server [String] remote host to send rsynced content to
    # @param dryrun [Boolean] whether or not to use '--dry-run'
    def deploy_repos(yum_path, origin_server, destination_server, dryrun = false)
      rsync_command = repo_deployment_command(yum_path, yum_path, destination_server, dryrun)

      Pkg::Util::Net.remote_ssh_cmd(origin_server, rsync_command)
    end
  end
end
