# The pl:load_extras tasks is intended to load variables
# from the extra yaml file downloaded by the pl:fetch task.
# The goal is to be able to augment/override settings in the
# source project's build_data.yaml and project_data.yaml with
# Puppet Labs-specific data, rather than having to clutter the
# generic tasks with data not generally useful outside the
# PL Release team
namespace :pl do
  task :load_extras, :tempdir do |t, args|
    unless ENV['PARAMS_FILE'] && ENV['PARAMS_FILE'] != ''
      tempdir = args.tempdir
      fail "pl:load_extras requires a directory containing extras data" if tempdir.nil?
      Pkg::Config.config_from_yaml("#{tempdir}/#{Pkg::Config.builder_data_file}")

      # Environment variables take precedence over those loaded from configs,
      # so we make sure that any we clobbered are reset.
      Pkg::Config.load_envvars
    end
  end
end

