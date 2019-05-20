module Pkg::Archive
  module_function

  # Array of base paths for foss artifacts on weth
  def base_paths
    [Pkg::Config.yum_repo_path, Pkg::Config.apt_repo_staging_path, Pkg::Config.apt_repo_path, '/opt/downloads'].compact.freeze
  end

  # Array of paths for temporarily staging artifacts before syncing to release-archives on s3
  def archive_paths
    [Pkg::Config.yum_archive_path, Pkg::Config.apt_archive_path, Pkg::Config.freight_archive_path, Pkg::Config.downloads_archive_path, '/opt/tmp-apt'].compact.freeze
  end

  # Move yum directories from repo path to archive staging path
  def stage_yum_archives(directory)
    # /opt/repository/yum/#{directory}
    full_directory = File.join(Pkg::Config.yum_repo_path, directory)
    archive_path = File.join(Pkg::Config.yum_archive_path, directory)
    command = <<-CMD
      if [ ! -d #{full_directory} ]; then
        if [ -d #{archive_path} ]; then
          echo "Directory #{full_directory} has already been staged, skipping . . ."
          exit 0
        else
          echo "ERROR: Couldn't find directory #{full_directory}, exiting . . ."
          exit 1
        fi
      fi
      find #{full_directory} -type l -delete
      sudo chattr -i -R #{full_directory}
      sudo mkdir --parents #{File.dirname(archive_path)}
      sudo chown root:release -R #{Pkg::Config.yum_archive_path}
      sudo chmod g+w -R #{Pkg::Config.yum_archive_path}
      mv #{full_directory} #{archive_path}
    CMD
    Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
  end

  # Move directories from freight path (aka repo staging path) to archive staging paths
  def stage_apt_archives(directory)
    find_command = "find #{Pkg::Config.apt_repo_staging_path} -type d -name #{directory}"
    find_command = "find #{Pkg::Config.apt_repo_staging_path} -maxdepth 2 -type f" if directory == 'main'
    command = <<-CMD
      for stuff in $(#{find_command}); do
        find $stuff -type l -delete
        codename=$(dirname ${stuff##{Pkg::Config.apt_repo_staging_path}/})
        sudo mkdir --parents #{Pkg::Config.freight_archive_path}/$codename
        sudo chown root:release -R #{Pkg::Config.freight_archive_path}/$codename
        sudo chmod g+w -R #{Pkg::Config.freight_archive_path}/$codename
        mv $stuff #{Pkg::Config.freight_archive_path}/$codename

        pool_directory=#{Pkg::Config.apt_repo_path}/pool/$codename/#{directory}
        if [ ! -d $pool_directory ]; then
          echo "Can't find directory $pool_directory, it may have already been archived, skipping . . ."
          continue
        fi
        sudo mkdir --parents /opt/tmp-apt
        sudo chown root:release -R /opt/tmp-apt
        sudo chmod g+w -R /opt/tmp-apt
        mv $pool_directory /opt/tmp-apt
      done
    CMD
    Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
  end

  # Move downloads directories to archive staging path
  def stage_downloads_archives(directory)
    # /opt/downloads/#{directory}
    full_directory = File.join('/', 'opt', 'downloads', directory)
    archive_path = File.join(Pkg::Config.downloads_archive_path, directory)
    command = <<-CMD
      if [ ! -d #{full_directory} ]; then
        if [ -d #{archive_path} ]; then
          echo "Directory #{full_directory} has already been staged, skipping . . ."
          exit 0
        else
          echo "ERROR: Couldn't find directory #{full_directory}, exiting . . ."
          exit 1
        fi
      fi
      find #{full_directory} -type l -delete
      sudo chattr -i -R #{full_directory}
      sudo mkdir --parents #{File.dirname(archive_path)}
      sudo chown root:release -R #{Pkg::Config.downloads_archive_path}
      sudo chmod g+w -R #{Pkg::Config.downloads_archive_path}
      mv #{full_directory} #{archive_path}
    CMD
    Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
  end

  # Delete empty directories from repo paths on weth
  def remove_empty_directories
    base_paths.each do |path|
      command = <<-CMD
        for directory in $(find #{path} -type d); do
          if [ ! -d $directory ]; then
            echo "Can't find directory $directory, it was probably already deleted, skipping . . ."
            continue
          fi
          files=$(find $directory -type f)
          if [ -z "$files" ]; then
            echo "No files in directory $directory, deleting . . ."
            sudo rm -rf $directory
          fi
        done
      CMD
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
    end
  end

  # Delete broken symlinks from repo paths on weth
  def remove_dead_symlinks
    base_paths.each do |path|
      command = "find #{path} -xtype l -delete"
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
    end
  end

  # Delete artifacts from archive staging paths (after they've been synced to s3)
  def delete_staged_archives
    archive_paths.each do |archive_path|
      command = "sudo rm -rf #{File.join(archive_path, '*')}"
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
    end
  end
end
