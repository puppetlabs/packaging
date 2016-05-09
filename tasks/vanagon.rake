namespace :vanagon do
  # vanagon:check_tags is used to report the tagged status of vanagon components
  # with "ref" fields indicated in their json files. This function does not create
  # any barriers or stop execution, it's only a report
  desc "Check for tagged components in vanagon projects"
  task :check_tags do
    # only available to vanagon projects
    unless Pkg::Config.vanagon_project
      puts "This is not a vanagon project"
      return
    end
    puts "*" * (ENV["COLUMNS"] || 70).to_i
    Pkg::Util.in_project_root do
      Pkg::Util::File.files_with_ext("configs/components", ".json").each do |json_file|
        json_data = Pkg::Util::Misc.load_from_json(json_file)
        # Don't report on anything without a ref
        if json_data["ref"].is_a?(String)
          Pkg::Util::Version.report_json_tags(json_data)
        end
      end
    end
  end

  # This is just a wrapper for uber_build that runs the check_tags report and
  # pauses for input, mainly so we can manually check for tagged components
  # before spending time on a build
  desc "Run component tag reports, if the report is okay, run an uber_build"
  task :build_all, [:poll_interval] do |t, args|
    args.with_defaults(:poll_interval => 0)
    Rake::Task["vanagon:check_tags"].invoke
    puts "Does this look correct?"
    return unless Pkg::Util.ask_yes_or_no
    Rake::Task["pl:jenkins:uber_build"].invoke(args.poll_interval)
  end
end
