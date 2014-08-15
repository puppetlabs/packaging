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
      invoke_task("pl:sign_rpms", "repos")
      Pkg::Rpm::Repo.create_repos('repos')
      Pkg::Deb::Repo.sign_repos('repos', 'Apt repository for nightly builds')
    end

    task :ship_nightly_repos => "pl:fetch" do
      target_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/nightly_repos"
      retry_on_fail(:times => 3) do
        # Ship the now signed repos to the distribution server
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir -p #{target_dir}")
        Pkg::Util::Net.rsync_to("nightly_repos/", Pkg::Config.distribution_server, "#{target_dir} --ignore-existing")
      end
    end

    task :deploy_nightly_repos, [:target_host, :target_basedir] => ["clean", "pl:fetch"] do |t, args|
      target_host = args.target_host or fail ":target_host is a required argument to #{t}"
      target_basedir = args.target_basedir or fail ":target_basedir is a required argument to #{t}"
      mkdir("pkg")

      Dir.chdir("pkg") do
        local_target = File.join(Pkg::Config.project, Pkg::Config.ref)
        mkdir_p(local_target)

        # Rake task dependencies with arguments are nuts, so we just directly
        # invoke them here.  We want the nightly_* directories staged as
        # repos/repo_configs, because that's how we want them on the public
        # server
        invoke_task("pl:jenkins:retrieve", "nightly_repos", File.join(local_target, "repos"))
        invoke_task("pl:jenkins:retrieve", "nightly_repo_configs", File.join(local_target, "repo_configs"))

        # The repo configs have Pkg::Config.builds_server used in them, but that
        # is internal, so we need to replace it with our public server. We also
        # want them only to see repos, and not nightly repos, since the host is
        # called nightlies.puppetlabs.com. Here we replace those values in each
        # config with the desired value.
        Dir.glob("#{local_target}/repo_configs/**/*").select {|t_config| File.file?(t_config) }.each do |config|
          new_contents = File.read(config).gsub(Pkg::Config.builds_server, target_host).gsub(/nightly_repos/, "repos")
          File.open(config, "w") { |file| file.puts new_contents }
        end

        # Make a latest symlink for the project
        FileUtils.ln_s(local_target, "#{Pkg::Config.project}-latest")
      end

      # Ship it to the target for consumption
      Pkg::Util::Net.rsync_to("pkg/", target_host, target_basedir)
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
      puts "Shipped #{Pkg::Config.ref} of #{Pkg::Config.project} into the nightly repos."
    end
  end
end
