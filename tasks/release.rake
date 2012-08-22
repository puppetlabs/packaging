namespace :package do
  desc "Update the version in #{@version_file} to current and commit."
  task :versionbump  do
    old_version =  get_version_file_version
    contents = IO.read(@version_file)
    new_version = '"' + get_version.to_s.strip + '"'
    if contents.match("VERSION = #{old_version}")
      contents.gsub!("VERSION = #{old_version}", "VERSION = #{new_version}")
    else
      contents.gsub!("#{@name.upcase}VERSION = #{old_version}", "#{@name.upcase}VERSION = #{new_version}")
    end
    file = File.open(@version_file, 'w')
    file.write contents
    file.close
    git_commit_file(@version_file)
  end
end

