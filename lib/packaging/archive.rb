module Pkg::Archive
  module_function

  def base_paths
    [Pkg::Config.yum_repo_path, Pkg::Config.apt_repo_staging_path, Pkg::Config.apt_repo_path, '/opt/downloads'].compact.freeze
  end

  def archive_paths
    [Pkg::Config.yum_archive_path, Pkg::Config.apt_archive_path, Pkg::Config.freight_archive_path, Pkg::Config.downloads_archive_path].compact.freeze
  end

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

  def stage_apt_archives(directory)
    # /opt/tools/freight/apt/$codename/#{directory}
    # /opt/repository/apt/pool/$codename/#{directory}
    pool_directory = File.join(Pkg::Config.apt_repo_path, 'pool')
    command = <<-CMD
      for full_directory in $(find #{pool_directory} -type d -name #{directory}); do
        find $full_directory -type l -delete
        sudo chattr -i -R $full_directory
        subdirectory=${full_directory##{Pkg::Config.apt_repo_path}/}
        codename=$(echo $subdirectory | cut -d'/' -f 2)
        sudo mkdir --parents #{Pkg::Config.apt_archive_path}/$subdirectory
        sudo chown root:release -R #{Pkg::Config.apt_archive_path}/$subdirectory
        sudo chmod g+w -R #{Pkg::Config.apt_archive_path}/$subdirectory
        mv $full_directory #{Pkg::Config.apt_archive_path}/$(dirname $subdirectory)
        sudo mkdir --parents #{Pkg::Config.freight_archive_path}/$codename
        sudo chown root:release -R #{Pkg::Config.freight_archive_path}/$codename
        sudo chmod g+w -R #{Pkg::Config.freight_archive_path}/$codename
        if [ #{directory} = 'main' ]; then
          freight_directory=#{Pkg::Config.apt_repo_staging_path}/$codename
          if [ ! -d $freight_directory ]; then
            echo "ERROR: Couldn't find freight directory $freight_directory, exiting . . ."
            exit 1
          fi
          for file in $(find $freight_directory -maxdepth 1 -type f); do
            mv $file #{Pkg::Config.freight_archive_path}/$codename
          done
        else
          freight_directory=#{Pkg::Config.apt_repo_staging_path}/$codename/#{directory}
          if [ ! -d $freight_directory ]; then
            if [ -d #{Pkg::Config.freight_archive_path}/$codename/#{directory} ]; then
              echo "Directory $freight_directory has already been staged, skipping . . ."
              exit 0
            else
              echo "ERROR: Couldn't find freight directory $freight_directory, exiting . . ."
              exit 1
            fi
          fi
          mv $freight_directory #{Pkg::Config.freight_archive_path}/$codename/#{directory}
        fi
      done
    CMD
    Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
  end

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

  def remove_dead_symlinks
    base_paths.each do |path|
      command = "find #{path} -xtype l -delete"
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
    end
  end

  def delete_staged_archives
    archive_paths.each do |archive_path|
      command = "sudo rm -rf #{File.join(archive_path, '*')}"
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
    end
  end
end
