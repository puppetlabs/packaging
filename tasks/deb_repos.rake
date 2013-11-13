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
    task :deb_repos => "pl:fetch" do
      prefix = Pkg::Config.build_pe ? "pe/" : ""

      # First, we test that artifacts exist and set up the repos directory
      artifact_directory = File.join(Pkg::Config.jenkins_repo_path, Pkg::Config.project, Pkg::Config.ref)

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
      cmd << 'for dist in $dists ; do mkdir -p $dist/conf ; pushd $dist ;
      echo "
Origin: Puppet Labs
Label: Puppet Labs
Codename: $dist
Architectures: i386 amd64
Components: main
Description: Apt repository for acceptance testing" >> conf/distributions ; '

      # Create the repositories using reprepro. Since these are for acceptance
      # testing only, we'll just add the debs and ignore source files for now.
      #
      cmd << "reprepro=$(which reprepro) ; "
      cmd << "$reprepro includedeb $dist ../../#{prefix}deb/$dist/*.deb ; popd ; done ; "
      cmd << "popd ; popd "

      begin
        remote_ssh_cmd(Pkg::Config.distribution_server, cmd)
        # Now that we've created our package repositories, we can generate repo
        # configurations for use with downstream jobs, acceptance clients, etc.
        Rake::Task["pl:jenkins:generate_deb_repo_configs"].execute

        # Now that we've created the repo configs, we can ship them
        Rake::Task["pl:jenkins:ship_repo_configs"].execute
      ensure
        # Always remove the lock file, even if we've failed
        remote_ssh_cmd(Pkg::Config.distribution_server, "rm -f #{artifact_directory}/.lock")
      end

    end

    # Generate apt configuration files that point to the repositories created
    # on the distribution server with packages created from the current source
    # repo commit. There is one for each dist that is packaged for (e.g. lucid,
    # squeeze, etc). Files are created in pkg/repo_configs/deb and are named
    # pl-$project-$sha.list, and can be placed in /etc/apt/sources.list.d to
    # enable clients to install these packages.
    #
    desc "Create apt repository configs for package repos for this sha/tag on the distribution server"
    task :generate_deb_repo_configs => "pl:fetch" do

      # This is the standard path to all debian build artifact repositories on
      # the distribution server for this commit
      #
      base_url = "http://#{Pkg::Config.builds_server}/#{Pkg::Config.project}/#{Pkg::Config.ref}/repos/apt/"

      # We use wget to obtain a directory listing of what are presumably our deb repos
      #
      repo_urls = []
      wget = Pkg::Util::Tool.find_tool("wget") or fail "Could not find `wget` tool. This is needed for composing the debian repo configurations. Install `wget` and try again."
      # First test if the directory even exists
      #
      wget_results = %x{#{wget} --spider -r -l 1 --no-parent #{base_url} 2>&1}
      if $?.success?
        # We want to exclude index and robots files and only include the http: prefixed elements
        repo_urls = wget_results.split.uniq.reject{|x| x=~ /\?|index|robots/}.select{|x| x =~ /http:/}.map{|x| x.chomp('/')}
      else
        fail "No debian repos available for #{Pkg::Config.project} at #{Pkg::Config.ref}."
      end

      # Create apt sources.list files that can be added to hosts for installing
      # these packages. We use the list of distributions to create a config
      # file for every distribution.
      #
      mkdir_p File.join("pkg", "repo_configs", "deb")
      repo_urls.each do |url|
        # We want to skip the base_url, which wget returns as one of the results
        next if "#{url}/" == base_url
        dist = url.split('/').last
        repoconfig = ["# Packages for #{Pkg::Config.project} built from ref #{Pkg::Config.ref}",
                      "deb #{url} #{dist} main"]
        config = File.join("pkg", "repo_configs", "deb", "pl-#{Pkg::Config.project}-#{Pkg::Config.ref}-#{dist}.list")
        File.open(config, 'w') { |f| f.puts repoconfig }
      end
      puts "Wrote apt repo configs for #{Pkg::Config.project} at #{Pkg::Config.ref} to pkg/repo_configs/deb."
    end

    desc "Retrieve debian apt repository configs for this sha"
    task :deb_repo_configs => "pl:fetch" do
      wget = Pkg::Util::Tool.find_tool("wget") or fail "Could not find `wget` tool. This is needed for composing the debian repo configurations. Install `wget` and try again."
      mkdir_p "pkg/repo_configs"
      config_url = "#{Pkg::Config.builds_server}/#{Pkg::Config.project}/#{Pkg::Config.ref}/repo_configs/deb/"
      begin
        sh "#{wget} -r -np -nH --cut-dirs 3 -P pkg/repo_configs --reject 'index*' #{config_url}"
      rescue
        fail "Couldn't retrieve deb apt repo configs. See preceding http response for more info."
      end
    end
  end
end
