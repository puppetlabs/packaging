# The pl:load_extras tasks is intended to load variables
# from the extra yaml file downloaded by the pl:fetch task.
# The goal is to be able to augment/override settings in the
# source project's build_data.yaml and project_data.yaml with
# Puppet Labs-specific data, rather than having to clutter the
# generic tasks with data not generally useful outside the
# PL Release team
namespace :pl do
  task :load_extras do
    begin
      @team_data = YAML.load_file("#{ENV['HOME']}/.packaging/team/#{@builder_data_file}")
      @project_data = YAML.load_file("#{ENV['HOME']}/.packaging/project/#{@builder_data_file}")
      @pe_version       = @project_data['pe_version']    if @project_data['pe_version']
      @pe_name          = @project_data['pe_name']       if @project_data['pe_name']
      @tarball_path     = @project_data['tarball_path']  if @project_data['tarball_path']
      @rpm_build_host   = @team_data['rpm_build_host']   if @team_data['rpm_build_host']
      @deb_build_host   = @team_data['deb_build_host']   if @team_data['deb_build_host']
      @osx_build_host   = @team_data['osx_build_host']   if @team_data['osx_build_host']
      @ips_build_host   = @team_data['ips_build_host']   if @team_data['ips_build_host']
      @dmg_path         = @team_data['dmg_path']         if @team_data['dmg_path']
      @team             = @team_data['team']             if @team_data['team']
      @yum_repo_path    = @team_data['yum_repo_path']    if @team_data['yum_repo_path']
      @apt_repo_path    = @team_data['apt_repo_path']    if @team_data['apt_repo_path']
      @freight_conf     = @team_data['freight_conf']     if @team_data['freight_conf']
      @sles_build_host  = @team_data['sles_build_host']  if @team_data['sles_build_host']
      @sles_arch_repos  = @team_data['sles_arch_repos']  if @team_data['sles_arch_repos']
      @sles_repo_path   = @team_data['sles_repo_path']   if @team_data['sles_repo_path']
      @sles_repo_host   = @team_data['sles_repo_host']   if @team_data['sles_repo_host']
      @ips_path         = @team_data['ips_path']         if @team_data['ips_path']
      @ips_package_host = @team_data['ips_package_host'] if @team_data['ips_package_host']
      @certificate_pem  = @team_data['certificate_pem']  if @team_data['certificate_pem']
      @privatekey_pem   = @team_data['privatekey_pem']   if @team_data['privatekey_pem']
      @ips_inter_cert   = @team_data['ips_inter_cert']   if @team_data['ips_inter_cert']
      # Overrideable
      @build_pe         = (boolean_value( ENV['PE'] || @team_data['build_pe'])) if @team_data['build_pe']
      @cows             = (ENV['COW']      || @project_data['cows'])        if @project_data['cows']
      @final_mocks      = (ENV['MOCK']     || @project_data['final_mocks']) if @project_data['final_mocks']
      @packager         = (ENV['PACKAGER'] || @team_data['packager'])    if @team_data['packager']
    rescue => e
      STDERR.puts "There was an error loading the builder data from #{ENV['HOME']}/.packaging/#{@builder_data_file}. Try rake pl:fetch to download the current extras builder data.\n" + e.message
      STDERR.puts e.backtrace
      exit 1
    end
  end
end
if @team == 'release'
  @benchmark = TRUE
end

# Starting with puppetdb, we'll maintain two separate build-data files, one for PE and the other for FOSS
# This is the start to maintaining both PE and FOSS packaging in one source repo
if @pe_name
  @name = @pe_name
end
