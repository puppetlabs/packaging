# The pl:load_extras tasks is intended to load variables
# from the extra yaml file downloaded by the pl:fetch task.
# The goal is to be able to augment/override settings in the
# source project's build_data.yaml and project_data.yaml with
# Puppet Labs-specific data, rather than having to clutter the
# generic tasks with data not generally useful outside the
# PL Release team
namespace :pl do
  task :load_extras do
    unless ENV['PARAMS_FILE'] && ENV['PARAMS_FILE'] != ''
      @build.set_params_from_file("#{ENV['HOME']}/.packaging/team/#{@build.builder_data_file}")
      @build.set_params_from_file("#{ENV['HOME']}/.packaging/project/#{@build.builder_data_file}")
      # Overrideable
      @build.build_pe   = boolean_value(ENV['PE_BUILD']) if ENV['PE_BUILD']
      # right now, puppetdb is the only one to override these, because it needs
      # two sets of cows, one for PE and the other for FOSS
      @build.cows             = ENV['COW']      if ENV['COW']
      @build.final_mocks      = ENV['MOCK']     if ENV['MOCK']
      @build.packager         = ENV['PACKAGER'] if ENV['PACKAGER']
      @build.pe_version       ||= ENV['PE_VER'] if ENV['PE_VER']
      @build.yum_repo_path    = ENV['YUM_REPO'] if ENV['YUM_REPO']
      @build.yum_host         = ENV['YUM_HOST'] if ENV['YUM_HOST']
      @build.apt_host         = ENV['APT_HOST'] if ENV['APT_HOST']
      @build.apt_repo_path    = ENV['APT_REPO'] if ENV['APT_REPO']
    end
  end
end
if @build.team == 'release'
  @build.benchmark = TRUE
end

# Starting with puppetdb, we'll maintain two separate build-data files, one for PE and the other for FOSS
# This is the start to maintaining both PE and FOSS packaging in one source repo
unless @build.pe_name.nil?
  @build.project = @build.pe_name
end
