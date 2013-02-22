##
# Create a debian repository under the standard pkg/ directory layout that the
# packaging repo creates. The standard layout is pkg/deb/$distribution/files.
# The repository is created in the 'repos' directory under the jenkins build
# directories on the distribution server, e.g.
# /opt/jenkins-builds/$project/$sha/repos. Because we're creating deb
# repositories on the fly, we have to generate the configuration files as well.
# We assume every directory under the `deb` directory is named for a
# distribution, and we use this in creating our configurations.
#
namespace :pl do
  namespace :jenkins do
    desc "Create apt repositories of build DEB packages for this SHA on the distributions erver"
    task :deb_repos => ["pl:fetch", "pl:load_extras"] do

      # First, we test that artifacts exist and set up the repos directory
      artifact_directory = File.join(@build.jenkins_repo_path, @build.project, git_sha.strip)

      cmd = 'echo " Checking for deb build artifacts. Will exit if not found.." ; '
      cmd << "[ -d #{artifact_directory}/artifacts/deb ] || exit 0 ; "
      cmd << "pushd #{artifact_directory} ; "
      cmd << "rsync -avxl artifacts/ repos/ && pushd repos ; "

      # Descend into the deb directory and obtain the list of distributions
      # we'll be building repos for
      cmd << "pushd deb && dists=$(ls) && popd; "

      # We do one more check here to make sure we actually have distributions
      # to build for. If deb is empty we want to just exit.
      #
      cmd << '[ -n "$dists" ] || exit 0 ; '

      # Make the conf directory and write out our configuration file
      cmd << "rm -rf apt && mkdir -p apt/conf && pushd apt ; "
      cmd << 'for dist in $dists ; do
      echo "
Origin: Puppet Labs
Label: Puppet Labs
Codename: $dist
Architectures: i386 amd64
Components: main
Description: Apt repository for acceptance testing" >> conf/distributions ; done ; '

      # Create the repositories using reprepro. Since these are for acceptance
      # testing only, we'll just add the debs and ignore source files for now.
      #
      cmd << "reprepro=$(which reprepro) ; "
      cmd << "for dist in $dists ; do "
      cmd << "$reprepro includedeb $dist ../deb/$dist/*.deb ; done"

      remote_ssh_cmd(@build.distribution_server, cmd)

      # Now that we've created our package repositories, we can generate repo
      # configurations for use with downstream jobs, acceptance clients, etc.
      Rake::Task["pl:jenkins:deb_repo_configs"].execute
    end

    # Generate apt configuration files that point to the repositories created
    # on the distribution server with packages created from the current source
    # repo commit. There is one for each dist that is packaged for (e.g. lucid,
    # squeeze, etc). Files are created in pkg/repo_configs/deb and are named
    # pl-$project-$sha.list, and can be placed in /etc/apt/sources.list.d to
    # enable clients to install these packages.
    #
    desc "Create apt repository configs for package repos for this sha on the distribution server"
    task :deb_repo_configs => ["pl:fetch", "pl:load_extras"] do

      # This is the standard path to all build artifacts on the distribution
      # server for this commit
      #
      artifact_directory = File.join(@build.jenkins_repo_path, @build.project, git_sha.strip)

      # We obtain the list of distributions in the debian repository with some hackery.
      #
      dists = %x{ssh -t #{@build.distribution_server} 'ls #{artifact_directory}/repos/apt/dists'}.split

      # Create apt sources.list files that can be added to hosts for installing
      # these packages. We use the list of distributions to create a config
      # file for every distribution.
      #
      mkdir_p File.join("pkg", "repo_configs", "deb")
      dists.each do |dist|
        repoconfig = ["# Packages for #{@build.project} built from commit #{git_sha.strip}",
                      "deb http://#{@build.builds_server}/#{@build.project}/#{git_sha.strip}/repos/apt #{dist} main"]
        config = File.join("pkg", "repo_configs", "deb", "pl-#{@build.project}-#{git_sha.strip}-#{dist}.list")
        File.open(config, 'w') { |f| f.puts repoconfig }
      end
      puts "Wrote apt repo configs for #{@build.project} at #{git_sha.strip} to pkg/repo_configs/deb."
    end
  end
end
