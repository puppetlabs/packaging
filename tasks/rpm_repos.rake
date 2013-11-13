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
      begin
        # Formulate our command string, which will just find directories with rpms
        # and create and update repositories.
        #
        artifact_directory = File.join(@build.jenkins_repo_path, @build.project, @build.ref)

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
        cmd << "pushd ${repodir} && ${createrepo} --checksum=sha --database --update . && popd ; "
        cmd << "done ; popd "

        remote_ssh_cmd(@build.distribution_server, cmd)
        # Now that we've created our repositories, we can create the configs for
        # them
        Rake::Task["pl:jenkins:generate_rpm_repo_configs"].execute

        # And once they're created, we can ship them
        Rake::Task["pl:jenkins:ship_repo_configs"].execute
      ensure
        # Always remove the lock file, even if we've failed
        remote_ssh_cmd(@build.distribution_server, "rm -f #{artifact_directory}/.lock")
      end
    end

    # Generate yum configuration files that point to the repositories created
    # on the distribution server with packages created from the current source
    # repo commit. There is one for each dist/version that is packaged (e.g.
    # el5, el6, etc). Files are created in pkg/repo_configs/rpm and are named
    # pl-$project-$sha.conf, and can be placed in /etc/yum.repos.d to enable
    # clients to install these packages.
    #
    desc "Create yum repository configs for package repos for this sha/tag on the distribution server"
    task :generate_rpm_repo_configs => "pl:fetch" do

      # We have a hard requirement on wget because of all the download magicks
      # we have to do
      #
      wget = Pkg::Util::Tool.find_tool("wget") or fail "Could not find `wget` tool. This is needed for composing the yum repo configurations. Install `wget` and try again."

      # This is the standard path to all build artifacts on the distribution
      # server for this commit
      #
      base_url = "http://#{@build.builds_server}/#{@build.project}/#{@build.ref}/repos/"

      # First check if the artifacts directory exists
      #

      # We have to do two checks here - first that there are directories with
      # repodata folders in them, and second that those same directories also
      # contain rpms
      #
      repo_urls = %x{#{wget} --spider -r -l 5 --no-parent #{base_url} 2>&1}.split.uniq.reject{ |x| x =~ /\?|index/ }.select{|x| x =~ /http:.*repodata\/$/}

      # RPMs will always exist at the same directory level as the repodata
      # folder, which means if we go up a level we should find rpms
      #
      yum_repos = []
      repo_urls.map{|x| x.chomp('repodata/')}.each do |url|
        unless %x{#{wget} --spider -r -l 1 --no-parent #{url} 2>&1}.split.uniq.reject{ |x| x =~ /\?|index/ }.select{|x| x =~ /http:.*\.rpm$/}.empty?
          yum_repos << url
        end
      end

      yum_repos.empty? and fail "No rpm repos were found to generate configs from!"

      mkdir_p File.join("pkg","repo_configs","rpm")

      # Parse the rpm configs file to generate repository configs. Each line in
      # the rpm_configs file corresponds with a repo directory on the
      # distribution server.
      #
      yum_repos.each do |url|
        # We ship a base 'srpm' that gets turned into a repo, but we want to
        # ignore this one because its an extra
        next if url == "#{base_url}srpm/"

        dist,version,_subdir,arch = url.split('/')[-4..-1]

        # Create an array of lines that will become our yum config
        #
        config = ["[pl-#{@build.project}-#{@build.ref}]"]
        config << ["name=PL Repo for #{@build.project} at commit #{@build.ref}"]
        config << ["baseurl=#{url}"]
        config << ["enabled=1"]
        config << ["gpgcheck=0"]

        # Write the new config to a file under our repo configs dir
        #
        config_file = File.join("pkg", "repo_configs", "rpm", "pl-#{@build.project}-#{@build.ref}-#{dist}-#{version}-#{arch}.repo")
        File.open(config_file, 'w') { |f| f.puts config }
      end
      puts "Wrote yum configuration files for #{@build.project} at #{@build.ref} to pkg/repo_configs/rpm"
    end

    desc "Retrieve rpm yum repository configs from distribution server"
    task :rpm_repo_configs => "pl:fetch" do
      wget = Pkg::Util::Tool.find_tool("wget") or fail "Could not find `wget` tool! wget is required to download the repository configs."
      mkdir_p "pkg/repo_configs"
      config_url = "#{@build.builds_server}/#{@build.project}/#{@build.ref}/repo_configs/rpm/"
      begin
        sh "#{wget} -r -np -nH --cut-dirs 3 -P pkg/repo_configs --reject 'index*' #{config_url}"
      rescue
        fail "Couldn't retrieve rpm yum repo configs. See preceding http response for more info."
      end
    end
  end
end
