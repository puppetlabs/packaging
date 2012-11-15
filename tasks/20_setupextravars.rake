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
      @build_data = YAML.load_file("#{ENV['HOME']}/.packaging/#{@builder_data_file}")
      @rpm_build_host   = @build_data['rpm_build_host']   if @build_data['rpm_build_host']
      @deb_build_host   = @build_data['deb_build_host']   if @build_data['deb_build_host']
      @osx_build_host   = @build_data['osx_build_host']   if @build_data['osx_build_host']
      @tarball_path     = @build_data['tarball_path']     if @build_data['tarball_path']
      @dmg_path         = @build_data['dmg_path']         if @build_data['dmg_path']
      @pe_version       = @build_data['pe_version']       if @build_data['pe_version']
      @team             = @build_data['team']             if @build_data['team']
      @yum_repo_path    = @build_data['yum_repo_path']    if @build_data['yum_repo_path']
      @apt_repo_path    = @build_data['apt_repo_path']    if @build_data['apt_repo_path']
      @freight_conf     = @build_data['freight_conf']     if @build_data['freight_conf']
      @sles_build_host  = @build_data['sles_build_host']  if @build_data['sles_build_host']
      @sles_arch_repos  = @build_data['sles_arch_repos']  if @build_data['sles_arch_repos']
      @sles_repo_path   = @build_data['sles_repo_path']   if @build_data['sles_repo_path']
      @sles_repo_host   = @build_data['sles_repo_host']   if @build_data['sles_repo_host']
      @ips_path         = @build_data['ips_path']         if @build_data['ips_path']
      @ips_package_host = @build_data['ips_package_host'] if @build_data['ips_package_host']
      @certificate_pem  = @build_data['certificate_pem']  if @build_data['certificate_pem']
      @privatekey_pem   = @build_data['privatekey_pem']   if @build_data['privatekey_pem']
      @ips_inter_cert   = @build_data['ips_inter_cert']   if @build_data['ips_inter_cert']
    rescue => e
      STDERR.puts "There was an error loading the builder data from #{ENV['HOME']}/.packaging/#{@builder_data_file}. Try rake pl:fetch to download the current extras builder data.\n" + e
      exit 1
    end
  end
end

