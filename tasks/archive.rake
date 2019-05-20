namespace :pl do
  namespace :remote do

    desc "Move packages from repo paths to archive staging paths"
    task :stage_archives, [:yum_directories, :apt_directories, :downloads_directories] => 'pl:fetch' do |_t, args|
      yum_directories = args.yum_directories ? args.yum_directories.split(' ') : []
      apt_directories = args.apt_directories ? args.apt_directories.split(' ') : []
      downloads_directories = args.downloads_directories ? args.downloads_directories.split(' ') : []

      yum_directories.each do |directory|
        Pkg::Archive.stage_yum_archives(directory)
      end
      apt_directories.each do |directory|
        Pkg::Archive.stage_apt_archives(directory)
      end
      downloads_directories.each do |directory|
        Pkg::Archive.stage_downloads_archives(directory)
      end
    end

    desc "Create archive yum repo"
    task :update_archive_yum_repo => 'pl:fetch' do
      Pkg::Repo.update_repo(Pkg::Config.staging_server, Pkg::Config.yum_repo_command, { :repo_name => '', :repo_path => Pkg::Config.yum_archive_path, :repo_host => Pkg::Config.staging_server })
    end

    desc "Create archive apt repo"
    task :update_archive_apt_repo => 'pl:fetch' do
      Pkg::Repo.update_repo(Pkg::Config.staging_server, Pkg::Config.apt_archive_repo_command)
    end

    desc "Sync archived packages to s3"
    task :deploy_staged_archives_to_s3 => 'pl:fetch' do
      command = 'sudo /usr/local/bin/s3_repo_sync.sh release-archives.puppet.com'
      Pkg::Util::Execution.retry_on_fail(:times => 3) do
        Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.staging_server, command)
      end
    end

    desc "Delete packages in archive staging directory"
    task :archive_cleanup => 'pl:fetch' do
      Pkg::Archive.remove_empty_directories
      Pkg::Archive.remove_dead_symlinks
      Pkg::Archive.delete_staged_archives
    end
  end
end

