# Utilities for working with rpm repos
require 'fileutils'

module Pkg::Rpm::Repo
  class << self
    def base_url
      "http://#{Pkg::Config.builds_server}/#{Pkg::Config.project}/#{Pkg::Config.ref}"
    end

    def ship_repo_configs(target = "repo_configs")
      Pkg::Util::File.empty_dir?("pkg/#{target}/rpm") and fail "No repo configs have been generated! Try pl:rpm_repo_configs."
      invoke_task("pl:fetch")
      repo_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/#{target}/rpm"
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir -p #{repo_dir}")
      retry_on_fail(:times => 3) do
        Pkg::Util::Net.rsync_to("pkg/#{target}/rpm/", Pkg::Config.distribution_server, repo_dir)
      end
    end

    def repo_creation_command(createrepo)
      cmd = 'for repodir in $(find ./ -name "*.rpm" | xargs -I {} dirname {}) ; do '
      cmd << "[ -d ${repodir} ] || continue; "
      cmd << "pushd ${repodir} && #{createrepo} --checksum=sha --database --update . ; popd ; "
      cmd << "done "
    end

    def create_repos(directory = "repos")
      Dir.chdir(directory) do
        createrepo = Pkg::Util::Tool.check_tool('createrepo')
        Pkg::Util::Execution.ex("bash -c '#{repo_creation_command(createrepo)}'")
      end
    end

    def retrieve_repo_configs(target = "repo_configs")
      wget = Pkg::Util::Tool.check_tool("wget")
      FileUtils.mkdir_p("pkg/#{target}")
      config_url = "#{base_url}/#{target}/rpm/"
      begin
        Pkg::Util::Execution.ex("#{wget} -r -np -nH --cut-dirs 3 -P pkg/#{target} --reject 'index*' #{config_url}")
      rescue
        fail "Couldn't retrieve rpm yum repo configs. See preceding http response for more info."
      end
    end

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
      repo_urls = Pkg::Util::Execution.ex("#{wget} --spider -r -l 5 --no-parent #{repo_base} 2>&1").split.uniq.reject{ |x| x =~ /\?|index/ }.select{ |x| x =~ /http:.*repodata\/$/ }

      # RPMs will always exist at the same directory level as the repodata
      # folder, which means if we go up a level we should find rpms
      #
      yum_repos = []
      repo_urls.map{ |x| x.chomp('repodata/') }.each do |url|
        unless Pkg::Util::Execution.ex("#{wget} --spider -r -l 1 --no-parent #{url} 2>&1").split.uniq.reject{ |x| x =~ /\?|index/ }.select{ |x| x =~ /http:.*\.rpm$/ }.empty?
          yum_repos << url
        end
      end

      yum_repos.empty? and fail "No rpm repos were found to generate configs from!"

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

    # Generate yum configuration files that point to the repositories created
    # on the distribution server with packages created from the current source
    # repo commit. There is one for each dist/version that is packaged (e.g.
    # el5, el6, etc). Files are created in pkg/repo_configs/rpm and are named
    # pl-$project-$sha.conf, and can be placed in /etc/yum.repos.d to enable
    # clients to install these packages.
    #
    def create_repos_from_artifacts
      begin
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
        cmd << "pushd ${repodir} && ${createrepo} --checksum=sha --database --update . ; popd ; "
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
    end
  end
end
