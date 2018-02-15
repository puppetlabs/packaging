module Pkg::Repo

  class << self
    def create_signed_repo_archive(path_to_repo, name_of_archive, versioning)
      tar = Pkg::Util::Tool.check_tool('tar')
      Dir.chdir("pkg") do
        if versioning == 'ref'
          local_target = File.join(Pkg::Config.project, Pkg::Config.ref)
        elsif versioning == 'version'
          local_target = File.join(Pkg::Config.project, Pkg::Util::Version.dot_version)
        end
        Dir.chdir(local_target) do
          if Pkg::Util::File.empty_dir?(path_to_repo)
            if ENV['FAIL_ON_MISSING_TARGET'] == "true"
              raise "ERROR: missing packages under #{path_to_repo}"
            else
              warn "Skipping #{name_of_archive} because #{path_to_repo} has no files"
            end
          else
            puts "Archiving #{path_to_repo} as #{name_of_archive}"
            stdout, _, _ = Pkg::Util::Execution.capture3("#{tar} --owner=0 --group=0 --create --gzip --file #{File.join('repos', "#{name_of_archive}.tar.gz")} #{path_to_repo}")
            stdout
          end
        end
      end
    end

    def create_all_repo_archives(project, versioning)
      platforms = Pkg::Config.platform_repos
      platforms.each do |platform|
        archive_name = "#{project}-#{platform['name']}"
        create_signed_repo_archive(platform['repo_location'], archive_name, versioning)
      end
    end

    def directories_that_contain_packages(artifact_directory, pkg_ext)
      cmd = "[ -d #{artifact_directory} ] || exit 1 ; "
      cmd << "pushd #{artifact_directory} > /dev/null && "
      cmd << "find . -name '*.#{pkg_ext}' -print0 | xargs --no-run-if-empty -0 -I {} dirname {} "
      stdout, stderr = Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, cmd, true)
      return stdout.split
    rescue => e
      fail "Could not retrieve directories that contain #{pkg_ext} packages in #{Pkg::Config.distribution_server}:#{artifact_directory}"
    end

    def populate_repo_directory(artifact_parent_directory)
      cmd = "[ -d #{artifact_parent_directory}/artifacts ] || exit 1 ; "
      cmd << "pushd #{artifact_parent_directory} > /dev/null && "
      cmd << 'rsync --archive --verbose --one-file-system --ignore-existing artifacts/ repos/ '
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, cmd)
    rescue => e
      fail "Could not populate repos directory in #{Pkg::Config.distribution_server}:#{artifact_parent_directory}"
    end

    def argument_required?(argument_name, repo_command)
      repo_command.include?("__#{argument_name.upcase}__")
    end

    def update_yum_repo(repo_name, repo_path, repo_host, command)
      fail "At least one of your arguments is nil, update your build_defaults?" unless repo_name && repo_path && repo_host && command
      yum_whitelist = {
        __REPO_NAME__: repo_name,
        __REPO_PATH__: repo_path,
        __REPO_HOST__: repo_host,
        __GPG_KEY__: Pkg::Util::Gpg.key
      }
      Pkg::Util::Net.remote_ssh_cmd(repo_host, Pkg::Util::Misc.search_and_replace(command, yum_whitelist))
    end

    def update_apt_repo(repo_name, repo_path, repo_host, repo_url, command)
      fail "At least one of your arguments is nil, update your build_defaults?" unless repo_name && repo_path && repo_host && repo_url && command
      apt_whitelist = {
        __REPO_NAME__: repo_name,
        __REPO_PATH__: repo_path,
        __REPO_HOST__: repo_host,
        __REPO_URL__: repo_url,
        __APT_PLATFORMS__: Pkg::Config.apt_releases.join(' '),
        __GPG_KEY__: Pkg::Util::Gpg.key
      }
      Pkg::Util::Net.remote_ssh_cmd(repo_host, Pkg::Util::Misc.search_and_replace(command, apt_whitelist))
    end
  end
end
