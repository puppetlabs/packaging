namespace :pl do
  ##
  # This crazy piece of work establishes a remote repo on the distribution
  # server, ships our repos out to it, signs them, and brings them back.
  # This is an INTERNAL rake task and should not be considered part of the packaging API.
  # Please do not depend on it.
  #
  namespace :jenkins do
    ##
    # This is to enable the work in CPR-52 to support nightly repos. For this
    # work we'll have signed repos for each package of a build.
    #
    task :remote_sign_nightly_repos => "pl:fetch" do
      target = "nightly_repos/"
      signing_server = Pkg::Config.signing_server
      # Sign the repos please
      Pkg::Util::File.empty_dir?("repos") and fail "There were no repos found in repos/. Maybe something in the pipeline failed?"
      signing_bundle = ENV['SIGNING_BUNDLE']

      remote_repo   = remote_bootstrap(signing_server, 'HEAD', nil, signing_bundle)
      build_params  = remote_buildparams(signing_server, Pkg::Config)
      Pkg::Util::Net.rsync_to('repos', signing_server, remote_repo)
      Pkg::Util::Net.remote_ssh_cmd(signing_server, "cd #{remote_repo} ; rake pl:jenkins:sign_nightly_repos GPG_KEY=#{Pkg::Config.gpg_key} PARAMS_FILE=#{build_params}")
      Pkg::Util::Net.rsync_from("#{remote_repo}/repos/", signing_server, target)
      Pkg::Util::Net.remote_ssh_cmd(signing_server, "rm -rf #{remote_repo}")
      Pkg::Util::Net.remote_ssh_cmd(signing_server, "rm #{build_params}")
      puts "Signed packages staged in '#{target}' directory"
    end

    task :sign_nightly_repos => "pl:fetch" do
      Pkg::Util::RakeUtils.invoke_task("pl:sign_rpms", "repos")
      Pkg::Rpm::Repo.create_repos('repos')
      Pkg::Deb::Repo.sign_repos('repos', 'Apt repository for nightly builds')
    end

    task :ship_nightly_repos => "pl:fetch" do
      target_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/nightly_repos"
      retry_on_fail(:times => 3) do
        # Ship the now signed repos to the distribution server
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir -p #{target_dir}")
        Pkg::Util::Net.rsync_to("nightly_repos/", Pkg::Config.distribution_server, target_dir)
      end
    end

    task :deploy_nightly_repos, [:target_host, :target_basedir] => ["clean", "pl:fetch"] do |t, args|
      target_host = args.target_host or fail ":target_host is a required argument to #{t}"
      target_basedir = args.target_basedir or fail ":target_basedir is a required argument to #{t}"
      mkdir("pkg")

      Dir.chdir("pkg") do
        local_target = File.join(Pkg::Config.project, Pkg::Config.ref)
        FileUtils.mkdir_p([local_target, Pkg::Config.project + "-latest"])

        # Rake task dependencies with arguments are nuts, so we just directly
        # invoke them here.  We want the nightly_* directories staged as
        # repos/repo_configs, because that's how we want them on the public
        # server
        Pkg::Util::RakeUtils.invoke_task("pl:jenkins:retrieve", "nightly_repos", File.join(local_target, "repos"))
        Pkg::Util::RakeUtils.invoke_task("pl:jenkins:retrieve", "nightly_repo_configs", File.join(local_target, "repo_configs"))

        # The repo configs have Pkg::Config.builds_server used in them, but that
        # is internal, so we need to replace it with our public server. We also
        # want them only to see repos, and not nightly repos, since the host is
        # called nightlies.puppetlabs.com. Here we replace those values in each
        # config with the desired value.
        Dir.glob("#{local_target}/repo_configs/**/*").select { |t_config| File.file?(t_config) }.each do |config|
          new_contents = File.read(config).gsub(Pkg::Config.builds_server, target_host).gsub(/nightly_repos/, "repos")
          File.open(config, "w") { |file| file.puts new_contents }
        end

        # Latest repo work. This little section does some magic to munge the
        # repo configs and link in the latest repos.  The repo_configs are
        # renamed to project-latest-$platform.{list,repo} to ensure that their
        # names stay the same between runs. Their contents have the ref
        # stripped off and the project replaced by $project-latest. Then the
        # repos directory is a symlink to the last pushed ref's repos.
        cp_pr(File.join(local_target, "repo_configs"), Pkg::Config.project + "-latest")

        # Now we need to remove the ref and replace $project with
        # $project-latest so that it will work as a pinned latest repo
        # Also rename the repo config to a static filename.
        Dir.glob("#{Pkg::Config.project}-latest/repo_configs/**/*").select { |t_config| File.file?(t_config) }.each do |config|
          new_contents = File.read(config)
          new_contents.gsub!(%r{#{Pkg::Config.ref}/}, "")
          new_contents.gsub!(%r{#{Pkg::Config.project}/}, Pkg::Config.project + "-latest/")
          new_contents.gsub!(Pkg::Config.ref, "latest")

          File.open(config, "w") { |file| file.puts new_contents }
          FileUtils.mv(config, config.gsub(Pkg::Config.ref, "latest"))
        end

        # Make a latest symlink for the project
        FileUtils.ln_s(File.join("..", local_target, "repos"), File.join(Pkg::Config.project + "-latest", "repos"))
      end

      # Ship it to the target for consumption
      # First we ship the latest and clean up any repo-configs that are no longer valid with --delete-after
      Pkg::Util::Net.rsync_to("pkg/#{Pkg::Config.project}-latest", target_host, target_basedir, ["--delete-after"])
      # Then we ship the sha version with default rsync flags
      Pkg::Util::Net.rsync_to("pkg/#{Pkg::Config.project}", target_host, target_basedir)

      puts "'#{Pkg::Config.ref}' of '#{Pkg::Config.project}' has been shipped to '#{target_host}:#{target_basedir}'"
    end

    task :generate_nightly_repo_configs => "pl:fetch" do
      Pkg::Rpm::Repo.generate_repo_configs('nightly_repos', 'nightly_repo_configs', true)
      Pkg::Deb::Repo.generate_repo_configs('nightly_repos', 'nightly_repo_configs')
    end

    task :ship_nightly_repo_configs => "pl:fetch" do
      Pkg::Rpm::Repo.ship_repo_configs('nightly_repo_configs')
      Pkg::Deb::Repo.ship_repo_configs('nightly_repo_configs')
    end

    task :nightly_repos => ["pl:fetch", "jenkins:remote_sign_nightly_repos", "jenkins:ship_nightly_repos", "jenkins:generate_nightly_repo_configs", "jenkins:ship_nightly_repo_configs"] do
      puts "Shipped '#{Pkg::Config.ref}' of '#{Pkg::Config.project}' into the nightly repos."
    end
  end
end
