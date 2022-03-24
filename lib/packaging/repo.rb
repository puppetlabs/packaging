module Pkg::Repo
  class << self
    ##
    ## Construct a local_target based upon the versioning style
    ##
    def construct_local_target_path(project, versioning)
      case versioning
      when 'ref'
        return File.join(project, Pkg::Config.ref)
      when 'version'
        return File.join(project, Pkg::Util::Version.dot_version)
      else
        fail "Error: Unknown versioning argument: #{versioning}"
      end
    end

    ##
    ## Put a single signed repo into a tarball stored in
    ## 'pkg/<local_target>/<archive_name>.tar.gz'
    ##
    def create_signed_repo_archive(repo_location, archive_name, versioning)
      tar = Pkg::Util::Tool.check_tool('tar')

      local_target = construct_local_target_path(Pkg::Config.project, versioning)

      if Pkg::Util::File.empty_dir?(File.join('pkg', local_target, repo_location))
        if ENV['FAIL_ON_MISSING_TARGET'] == "true"
          raise "Error: missing packages under #{repo_location}"
        end
        warn "Warn: Skipping #{archive_name} because #{repo_location} has no files"
        return
      end

      Dir.chdir(File.join('pkg', local_target)) do
        puts "Info: Archiving #{repo_location} as #{archive_name}"
        target_tarball = File.join('repos', "#{archive_name}.tar.gz")
        tar_command = %W[#{tar} --owner=0 --group=0 --create --gzip
          --file #{target_tarball} #{repo_location}].join(' ')
        stdout, = Pkg::Util::Execution.capture3(tar_command)
        return stdout
      end
    end

    ##
    ## Add a single repo tarball into the 'all' tarball located in
    ## 'pkg/<local_target>/<project>-all.tar'
    ## Create the 'all' tarball if needed.
    ##
    def update_tarball_of_all_repos(project, platform, versioning)
      tar = Pkg::Util::Tool.check_tool('tar')

      all_repos_tarball_name = "#{project}-all.tar"
      archive_name = "#{project}-#{platform['name']}"
      local_target = construct_local_target_path(project, versioning)
      repo_tarball_name = "#{archive_name}.tar.gz"
      repo_tarball_path = File.join('repos', repo_tarball_name)

      Dir.chdir(File.join('pkg', local_target)) do
        unless Pkg::Util::File.exist?(repo_tarball_path)
          warn "Skipping #{archive_name} because it (#{repo_tarball_path}) contains no files"
          next
        end

        tar_action = '--create'
        tar_action = '--update' if File.exist?(all_repos_tarball_name)

        tar_command = %W[#{tar} --owner=0 --group=0 #{tar_action}
          --file #{all_repos_tarball_name} #{repo_tarball_path}].join(' ')

        stdout, = Pkg::Util::Execution.capture3(tar_command)
        puts stdout
      end
    end

    ##
    ## Invoke gzip to compress the 'all' tarball located in
    ## 'pkg/<local_target>/<project>-all.tar'
    ##
    def compress_tarball_of_all_repos(all_repos_tarball_name)
      gzip = Pkg::Util::Tool.check_tool('gzip')

      gzip_command = "#{gzip} --fast #{all_repos_tarball_name}"
      stdout, = Pkg::Util::Execution.capture3(gzip_command)
      puts stdout
    end

    ##
    ## Generate each of the repos listed in <Config.platform_repos>.
    ## Update the 'all repos' tarball as we do each one.
    ## Compress the 'all repos' tarball when all the repos have been generated
    ##
    def create_all_repo_archives(project, versioning)
      platforms = Pkg::Config.platform_repos
      local_target = construct_local_target_path(project, versioning)
      all_repos_tarball_name = "#{project}-all.tar"

      platforms.each do |platform|
        archive_name = "#{project}-#{platform['name']}"
        create_signed_repo_archive(platform['repo_location'], archive_name, versioning)
        update_tarball_of_all_repos(project, platform, versioning)
      end

      Dir.chdir(File.join('pkg', local_target)) do
        compress_tarball_of_all_repos(all_repos_tarball_name)
      end
    end

    def directories_that_contain_packages(artifact_directory, pkg_ext)
      cmd = "[ -d #{artifact_directory} ] || exit 1 ; "
      cmd << "pushd #{artifact_directory} > /dev/null && "
      cmd << "find . -name '*.#{pkg_ext}' -print0 | xargs --no-run-if-empty -0 -I {} dirname {} "
      stdout, = Pkg::Util::Net.remote_execute(
        Pkg::Config.distribution_server,
                cmd,
                { capture_output: true }
      )
      return stdout.split
    rescue StandardError => e
      fail "Error: Could not retrieve directories that contain #{pkg_ext} " \
           "packages in #{Pkg::Config.distribution_server}:#{artifact_directory}: #{e}"
    end

    def populate_repo_directory(artifact_parent_directory)
      cmd = "[ -d #{artifact_parent_directory}/artifacts ] || exit 1 ; "
      cmd << "pushd #{artifact_parent_directory} > /dev/null && "
      cmd << 'rsync --archive --verbose --one-file-system --ignore-existing artifacts/ repos/ '
      Pkg::Util::Net.remote_execute(Pkg::Config.distribution_server, cmd)
    rescue StandardError => e
      fail "Error: Could not populate repos directory in " \
           "#{Pkg::Config.distribution_server}:#{artifact_parent_directory}: #{e}"
    end

    def argument_required?(argument_name, repo_command)
      repo_command.include?("__#{argument_name.upcase}__")
    end

    def update_repo(remote_host, command, options = {})
      fail_message = "Error: Missing required argument '%s', perhaps update build_defaults?"
      %i[repo_name repo_path repo_host repo_url].each do |option|
        fail fail_message % option.to_s if argument_required?(option.to_s, command) && !options[option]
      end

      repo_configuration = {
        __REPO_NAME__: options[:repo_name],
        __REPO_PATH__: options[:repo_path],
        __REPO_HOST__: options[:repo_host],
        __REPO_URL__: options[:repo_url],
        __APT_PLATFORMS__: Pkg::Config.apt_releases.join(' '),
        __GPG_KEY__: Pkg::Util::Gpg.key
      }
      Pkg::Util::Net.remote_execute(
        remote_host,
        Pkg::Util::Misc.search_and_replace(command, repo_configuration)
      )
    end
  end
end
