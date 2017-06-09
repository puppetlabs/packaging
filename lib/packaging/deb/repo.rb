# Utilities for working with deb repos
require 'fileutils'

module Pkg::Deb::Repo

  class << self
    def base_url
      "http://#{Pkg::Config.builds_server}/#{Pkg::Config.project}/#{Pkg::Config.ref}"
    end

    # Generate apt configuration files that point to the repositories created
    # on the distribution server with packages created from the current source
    # repo commit. There is one for each dist that is packaged for (e.g. lucid,
    # squeeze, etc). Files are created in pkg/repo_configs/deb and are named
    # pl-$project-$sha.list, and can be placed in /etc/apt/sources.list.d to
    # enable clients to install these packages.
    #
    def generate_repo_configs(source = "repos", target = "repo_configs")
      subrepo = Pkg::Config.repo_name || "main"
      # We use wget to obtain a directory listing of what are presumably our deb repos
      #
      wget = Pkg::Util::Tool.check_tool("wget")

      # This is the standard path to all debian build artifact repositories on
      # the distribution server for this commit
      #
      repo_base = "#{base_url}/#{source}/apt/"

      # First test if the directory even exists
      #
      begin
        stdout, _, _ = Pkg::Util::Execution.capture3("#{wget} --spider -r -l 1 --no-parent #{repo_base} 2>&1")
      rescue RuntimeError
        warn "No debian repos available for #{Pkg::Config.project} at #{Pkg::Config.ref}."
        return
      end

      # We want to exclude index and robots files and only include the http: prefixed elements
      repo_urls = stdout.split.uniq.reject { |x| x =~ /\?|index|robots/ }.select { |x| x =~ /http:/ }.map { |x| x.chomp('/') }


      # Create apt sources.list files that can be added to hosts for installing
      # these packages. We use the list of distributions to create a config
      # file for every distribution.
      #
      FileUtils.mkdir_p(File.join("pkg", target, "deb"))
      repo_urls.each do |url|
        # We want to skip the base_url, which wget returns as one of the results
        next if "#{url}/" == repo_base
        dist = url.split('/').last
        repoconfig = ["# Packages for #{Pkg::Config.project} built from ref #{Pkg::Config.ref}",
                      "deb #{url} #{dist} #{subrepo}"]
        config = File.join("pkg", target, "deb", "pl-#{Pkg::Config.project}-#{Pkg::Config.ref}-#{dist}.list")
        File.open(config, 'w') { |f| f.puts repoconfig }
      end
      puts "Wrote apt repo configs for #{Pkg::Config.project} at #{Pkg::Config.ref} to pkg/#{target}/deb."
    end

    def retrieve_repo_configs(target = "repo_configs")
      wget = Pkg::Util::Tool.check_tool("wget")
      FileUtils.mkdir_p("pkg/#{target}")
      config_url = "#{base_url}/#{target}/deb/"
      begin
        stdout, _, _ = Pkg::Util::Execution.capture3("#{wget} -r -np -nH --cut-dirs 3 -P pkg/#{target} --reject 'index*' #{config_url}")
        stdout
      rescue => e
        fail "Couldn't retrieve deb apt repo configs.\n#{e}"
      end
    end

    def repo_creation_command(prefix, artifact_directory)
      subrepo = Pkg::Config.repo_name || 'main'
      # First, we test that artifacts exist and set up the repos directory
      cmd = 'echo " Checking for deb build artifacts. Will exit if not found.." ; '
      cmd << "[ -d #{artifact_directory}/artifacts/#{prefix}deb ] || exit 1 ; "
      # Descend into the deb directory and obtain the list of distributions
      # we'll be building repos for
      cmd << "pushd #{artifact_directory}/artifacts/#{prefix}deb && dists=$(ls) && popd; "
      # We do one more check here to make sure we actually have distributions
      # to build for. If deb is empty we want to just exit.
      #
      cmd << '[ -n "$dists" ] || exit 1 ; '
      cmd << "pushd #{artifact_directory} ; "

      cmd << 'echo "Checking for running repo creation. Will wait if detected." ; '
      cmd << "while [ -f .lock ] ; do sleep 1 ; echo -n '.' ; done ; "
      cmd << 'echo "Setting lock" ; '
      cmd << "touch .lock ; "
      cmd << "rsync -avxl artifacts/ repos/ ; pushd repos ; "

      # Make the conf directory and write out our configuration file
      cmd << "rm -rf apt && mkdir -p apt ; pushd apt ; "
      cmd << %Q(for dist in $dists ; do mkdir -p $dist/conf ; pushd $dist ;
      echo "
Origin: Puppet Labs
Label: Puppet Labs
Codename: $dist
Architectures: i386 amd64 arm64 armel armhf powerpc ppc64el sparc mips mipsel
Components: #{subrepo}
Description: Apt repository for acceptance testing" >> conf/distributions ; )

      # Create the repositories using reprepro. Since these are for acceptance
      # testing only, we'll just add the debs and ignore source files for now.
      #
      cmd << "reprepro=$(which reprepro) ; "
      cmd << %Q($reprepro includedeb $dist ../../#{prefix}deb/$dist#{Pkg::Config.repo_name ? "/#{subrepo}" : ""}/*.deb ; popd ; done ; )
      cmd << "popd ; popd "

      return cmd
    end

    # This method is doing too much for its name
    def create_repos
      prefix = Pkg::Config.build_pe ? "pe/" : ""

      artifact_directory = File.join(Pkg::Config.jenkins_repo_path, Pkg::Config.project, Pkg::Config.ref)

      command = repo_creation_command(prefix, artifact_directory)

      begin
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, command)
        # Now that we've created our package repositories, we can generate repo
        # configurations for use with downstream jobs, acceptance clients, etc.
        Pkg::Deb::Repo.generate_repo_configs

        # Now that we've created the repo configs, we can ship them
        Pkg::Deb::Repo.ship_repo_configs
      ensure
        # Always remove the lock file, even if we've failed
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "rm -f #{artifact_directory}/.lock")
      end
    end

    def ship_repo_configs(target = "repo_configs")
      if (!File.exist?("pkg/#{target}/deb")) || Pkg::Util::File.empty_dir?("pkg/#{target}/deb")
        warn "No repo configs have been generated! Try pl:deb_repo_configs."
        return
      end

      invoke_task("pl:fetch")
      repo_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/#{target}/deb"
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir -p #{repo_dir}")
      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        Pkg::Util::Net.rsync_to("pkg/#{target}/deb/", Pkg::Config.distribution_server, repo_dir)
      end
    end

    def sign_repos(target = "repos", message = "Signed apt repository")
      subrepo = Pkg::Config.repo_name || 'main'
      reprepro = Pkg::Util::Tool.check_tool('reprepro')
      Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')

      dists = Pkg::Util::File.directories("#{target}/apt")

      if dists
        dists.each do |dist|
          Dir.chdir("#{target}/apt/#{dist}") do
            File.open("conf/distributions", "w") do |f|
              f.puts "Origin: Puppet Labs
Label: Puppet Labs
Codename: #{dist}
Architectures: i386 amd64 arm64 armel armhf powerpc ppc64el sparc mips mipsel
Components: #{subrepo}
Description: #{message} for #{dist}
SignWith: #{Pkg::Config.gpg_key}"
            end

            stdout, _, _ = Pkg::Util::Execution.capture3("#{reprepro} -vvv --confdir ./conf --dbdir ./db --basedir ./ export")
            stdout
          end
        end
      else
        warn "No repos found to sign. Maybe you didn't build any debs, or the repo creation failed?"
      end
    end

    # @deprecated this command will die a painful death when we are
    #   able to sit down with Operations and refactor our distribution infra.
    #   For now, it's extremely debian specific, which is why it lives here.
    #   - Ryan McKern 11/2015
    #
    # @param origin_path [String] path for Deb repos on local filesystem
    # @param destination_path [String] path for Deb repos on remote filesystem
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
        --itemize-changes
        --hard-links
        --copy-links
        --omit-dir-times
        --progress
        --archive
        --update
        --verbose
        --super
        --delay-updates
        --omit-dir-times
        --no-perms
        --no-owner
        --no-group
        --exclude='dists/*-*'
        --exclude='pool/*-*'
      )

      options << '--dry-run' if dryrun
      options << path
      if !destination.nil?
        options << "#{destination}:#{dest_path.parent}"
      else
        options << "#{dest_path.parent}"
      end
      options.join("\s")
    end

    # @deprecated this command will die a painful death when we are
    #   able to sit down with Operations and refactor our distribution infra.
    #   It's extremely Debian specific due to how Debian repos are signed,
    #   which is why it lives here.
    #   Yes, it is basically just a layer of indirection around the task
    #   of copying content from one node to another. No, I am not proud
    #   of it. - Ryan McKern 11/2015
    #
    # @param apt_path [String] path for Deb repos on local and remote filesystem
    # @param destination_staging_path [String] staging path for Deb repos on
    #        remote filesystem
    # @param origin_server [String] remote host to start the  rsync from
    # @param destination_server [String] remote host to send rsynced content to
    # @param dryrun [Boolean] whether or not to use '--dry-run'
    def deploy_repos(apt_path, destination_staging_path, origin_server, destination_server, dryrun = false)
      rsync_command = repo_deployment_command(apt_path, destination_staging_path, destination_server, dryrun)
      cp_command = repo_deployment_command(destination_staging_path, apt_path, nil, dryrun)

      Pkg::Util::Net.remote_ssh_cmd(origin_server, rsync_command)
      if dryrun
        puts "[DRYRUN] not executing #{cp_command} on #{destination_server}"
      else
        Pkg::Util::Net.remote_ssh_cmd(destination_server, cp_command)
      end
    end

  end
end
