##
#
# A set of functionality for creating yum rpm repositories throughout the
# standard pkg/ directory layout that the packaging repo creates. The standard
# layout is:
# pkg/{el,fedora}/{5,6,f16,f17,f18}/{products,devel,dependencies,extras}/{i386,x86_64,SRPMS}
#
# Because we'll likely be creating the repos on a server that is remote, e.g.
# the distribution server, the logic here assumes we'll be doing everything via
# ssh commands.
#
namespace :pl do
  namespace :jenkins do
    desc "Create yum repositories of built RPM packages for this SHA on the distribution server"
    task :rpm_repos => "pl:fetch" do
      # Formulate our command string, which will just find directories with rpms
      # and create and update repositories.
      #
      artifact_directory = File.join(@build.jenkins_repo_path, @build.project, git_sha.strip)

      ##
      # Test that the artifacts directory exists on the distribution server.
      # This will give us some more helpful output.
      #
      cmd = 'echo "Checking for build artifacts. Will exit if not found." ; '
      cmd << "[ -d #{artifact_directory}/artifacts ] || exit 0 ; "

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
      cmd << "pushd $repodir && $createrepo -d --update . && popd ; "
      cmd << "done ; popd ; rm .lock"

      remote_ssh_cmd(@build.distribution_server, cmd)

      # Now that we've created our repositories, we can create the configs for
      # them
      Rake::Task["pl:jenkins:rpm_repo_configs"].invoke
    end

    # Generate yum configuration files that point to the repositories created
    # on the distribution server with packages created from the current source
    # repo commit. There is one for each dist/version that is packaged (e.g.
    # el5, el6, etc). Files are created in pkg/repo_configs/rpm and are named
    # pl-$project-$sha.conf, and can be placed in /etc/yum.repos.d to enable
    # clients to install these packages.
    #
    desc "Create yum repository configs for package repos for this sha on the distribution server"
    task :rpm_repo_configs => "pl:fetch" do

      # This is the standard path to all build artifacts on the distribution
      # server for this commit
      #
      artifact_directory = File.join(@build.jenkins_repo_path, @build.project, git_sha.strip)
      # First check if the artifacts directory exists
      #
      cmd = "[ -d #{artifact_directory} ] || exit 0 ; "
      # Descend into the artifacts directory and test if we have any repos
      #
      cmd << "pushd #{artifact_directory} ; "
      cmd << 'echo "Checking if rpm repos exists, will exit if not.." ; '
      cmd << '[ -n "$(find repos -name "*.rpm")" ] || exit 0 ; '
      cmd << "pushd repos ; "

      cmd << 'for repo in $(find -name "repodata") ; do dirname $repo >> rpm_configs ; done'

      remote_ssh_cmd(@build.distribution_server, cmd)

      # There's a chance there were simply no rpms to make repos for. If so, we
      # don't want to proceed.
      %x{ssh -t #{@build.distribution_server} 'ls #{artifact_directory}/repos/rpm_configs'}
      unless $?.success?
        warn "No repos were found to generate configs from. Exiting.."
        exit 0
      end
      mkdir_p "pkg"
      rsync_from("#{artifact_directory}/repos/rpm_configs", @build.distribution_server, "pkg")

      # Clean up the remote configs file
      remote_ssh_cmd(@build.distribution_server, "rm #{artifact_directory}/repos/rpm_configs")

      if File.exist?(File.join("pkg", "rpm_configs"))
        mkdir_p File.join("pkg","repo_configs","rpm")

        # Parse the rpm configs file to generate repository configs. Each line in
        # the rpm_configs file corresponds with a repo directory on the
        # distribution server.
        #
        lines = IO.readlines(File.join("pkg","rpm_configs")).map{ |l| l.chomp }.uniq
        lines.each do |repo|
          dist,version,subdir,arch = repo.split('/')[1..4]

          # Skip any paths that don't have everything we're looking for, e.g.
          # the top-level srpms directory that contains the original srpm from
          # packaging
          next if dist.nil? or version.nil? or subdir.nil? or arch.nil?

          # Create an array of lines that will become our yum config
          #
          config = ["[pl-#{@build.project}-#{git_sha.strip}]"]
          config << ["name=PL Repo for #{@build.project} at commit #{git_sha.strip}"]
          config << ["baseurl=http://#{@build.builds_server}/#{@build.project}/#{git_sha.strip}/repos/#{dist}/#{version}/#{subdir}/#{arch}"]
          config << ["enabled=1"]
          config << ["gpgcheck=0"]

          # Write the new config to a file under our repo configs dir
          #
          config_file = File.join("pkg", "repo_configs", "rpm", "pl-#{@build.project}-#{git_sha.strip}-#{dist}-#{version}-#{arch}-#{subdir}.repo")
          File.open(config_file, 'w') { |f| f.puts config }
        end
        rm File.join("pkg","rpm_configs")
        puts "Wrote yum configuration files for #{@build.project} at #{git_sha.strip} to pkg/repo_configs/rpm"
      end
    end
  end
end
