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
  desc "Update the version in #{@build.version_file} to current and commit."
  task :versionbump, :workdir do |t, args|
    version = ENV['VERSION'] || @build.version.to_s.strip
    new_version = '"' + version + '"'

    version_file = "#{args.workdir ? args.workdir + '/' : ''}#{@build.version_file}"

    # Read the previous version file in...
    contents = IO.read(version_file)

    # Match version files containing 'VERSION = "x.x.x"' and just x.x.x
    if version_string = contents.match(/VERSION =.*/)
      old_version = version_string.to_s.split()[-1]
    else
      old_version = contents
    end

    puts "Updating #{old_version} to #{new_version} in #{version_file}"
    if contents.match("@DEVELOPMENT_VERSION@")
      contents.gsub!("@DEVELOPMENT_VERSION@", version)
    elsif contents.match('version\s*=\s*[\'"]DEVELOPMENT[\'"]')
      contents.gsub!(/version\s*=\s*['"]DEVELOPMENT['"]/, "version = '#{version}'")
    elsif contents.match("VERSION = #{old_version}")
      contents.gsub!("VERSION = #{old_version}", "VERSION = #{new_version}")
    elsif contents.match("#{@build.project.upcase}VERSION = #{old_version}")
      contents.gsub!("#{@build.project.upcase}VERSION = #{old_version}", "#{@build.project.upcase}VERSION = #{new_version}")
    else
      contents.gsub!(old_version, @build.version)
    end

    # ...and write it back on out.
    File.open(version_file, 'w') {|f| f.write contents }
  end

  desc "Set and commit the version in #{@build.version_file}, requires VERSION."
  task :versionset do
    check_var('VERSION', ENV['VERSION'])
    Rake::Task["package:versionbump"].invoke
    git_commit_file(@build.version_file, "update to #{ENV['VERSION']}")
  end

  # A set of tasks for printing the version
  [:version, :rpmversion, :rpmrelease, :debversion, :release].each do |task|
    task "#{task}" do
      STDOUT.puts self.instance_variable_get("@#{task}")
    end
  end
end

