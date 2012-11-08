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
  desc "Update the version in #{@version_file} to current and commit."
  task :versionbump  do
    old_version =  get_version_file_version
    contents = IO.read(@version_file)
    new_version = '"' + @version.to_s.strip + '"'
    if contents.match("@DEVELOPMENT_VERSION@")
      contents.gsub!("@DEVELOPMENT_VERSION@", @version.to_s.strip)
    elsif contents.match("VERSION = #{old_version}")
      contents.gsub!("VERSION = #{old_version}", "VERSION = #{new_version}")
    elsif contents.match("#{@name.upcase}VERSION = #{old_version}")
      contents.gsub!("#{@name.upcase}VERSION = #{old_version}", "#{@name.upcase}VERSION = #{new_version}")
    else
      contents.gsub!(old_version, @version)
    end
    file = File.open(@version_file, 'w')
    file.write contents
    file.close
  end
end

