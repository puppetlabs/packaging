# This is something of a work in progress. Unfortunately,
# many of the projects that use the packaging repo carry
# version files with hard-coded versions, and many of these
# are in completely disparate formats.
#
# This task attempts to automate the updating of this file
# with the version to be packaged, but given the many version
# file formats in use, doing so cleanly is difficult. With
# any luck, going forward some of these projects will move
# away from maintaining hard-coded versions in source.
# However, if this effort loses momentum, we may end up
# revisiting this task and improving it substantially,
# and/or standardizing the expected version file format.
namespace :package do
  desc "Set and commit the version in #{Pkg::Config.version_file}, requires VERSION."
  task :versionset do
    Pkg::Util.check_var('VERSION', ENV['VERSION'])
    Pkg::Util::Version.versionbump
    Pkg::Util::Git.commit_file(Pkg::Config.version_file, "update to #{ENV['VERSION']}")
  end

  task :versionbump, :workdir do |t, args|
    Pkg::Util::Version.versionbump(args.workdir)
  end

  # A set of tasks for printing the version
  [:version, :rpmversion, :rpmrelease, :debversion, :release].each do |task|
    task "#{task}" do
      $stdout.puts Pkg::Config.instance_variable_get("@#{task}")
    end
  end
end

