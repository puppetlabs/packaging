namespace :pl do
  task :load_extras do
    begin
      @build_data = YAML.load_file("#{ENV['HOME']}/.packaging/#{@builder_data_file}")
      @rpm_build_host   = @build_data['rpm_build_host']  if @build_data['rpm_build_host']
      @deb_build_host   = @build_data['deb_build_host']  if @build_data['deb_build_host']
      @osx_build_host   = @build_data['osx_build_host']  if @build_data['osx_build_host']
      @tarball_path     = @build_data['tarball_path']    if @build_data['tarball_path']
      @dmg_path         = @build_data['dmg_path']        if @build_data['dmg_path']
      @pe_version       = @build_data['pe_version']      if @build_data['pe_version']
      @team             = @build_data['team']            if @build_data['team']
      @yum_repo_path    = @build_data['yum_repo_path']   if @build_data['yum_repo_path']
      @apt_repo_path    = @build_data['apt_repo_path']   if @build_data['apt_repo_path']
      @freight_conf     = @build_data['freight_conf']    if @build_data['freight_conf']
      @sles_build_host  = @build_data['sles_build_host'] if @build_data['sles_build_host']
      @sles_arch_repos  = @build_data['sles_arch_repos'] if @build_data['sles_arch_repos']
      @sles_repo_path   = @build_data['sles_repo_path']  if @build_data['sles_repo_path']
      @sles_repo_host   = @build_data['sles_repo_host']  if @build_data['sles_repo_host']
    rescue => e
      STDERR.puts "There was an error loading the builder data from #{ENV['HOME']}/.packaging/#{@builder_data_file}. Try rake pl:fetch to download the current extras builder data.\n" + e
      exit 1
    end
  end
end

