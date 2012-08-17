task :versionbump  do
  old_version =  get_current_version
  contents = IO.read(@version_file)
  new_version = '"' + get_version.to_s.strip + '"'
  contents.gsub!("VERSION = #{old_version}", "VERSION = #{new_version}")
  file = File.open(@version_file, 'w')
  file.write contents
  file.close
end

