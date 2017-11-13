module Pkg::Retrieve
  module_function

  # --no-parent = Only descend when recursing, never ascend
  # --no-host-directories = Discard http://#{Pkg::Config.builds_server} when saving to disk
  # --level=0 = infinitely recurse, no limit
  # --cut-dirs 3 = will cut off #{Pkg::Config.project}, #{Pkg::Config.ref}, and the first directory in #{remote_target} from the url when saving to disk
  # --directory-prefix = where to save to disk (defaults to ./)
  # --reject = Reject all hits that match the supplied regex

  def default_wget(local_target, url)
    wget = Pkg::Util::Tool.check_tool('wget')
    wget_command = "#{wget} --quiet --recursive --no-parent --no-host-directories --level=0 --cut-dirs 3 --directory-prefix=#{local_target} --reject 'index*' #{url}"
    puts "Executing #{wget_command} . . ."
    %x(#{wget_command})
  end

  # This will always retrieve from under the 'artifacts' directory
  def foss_only_retrieve(build_url, local_target)
    unless Pkg::Config.foss_platforms
      fail "FOSS_ONLY specified, but I don't know anything about FOSS_PLATFORMS. Retrieve cancelled."
    end
    default_wget(local_target, "#{build_url}/artifacts/#{Pkg::Config.ref}.yaml")
    yaml_path = File.join(local_target, "#{Pkg::Config.ref}.yaml")
    unless File.readable?(yaml_path)
      fail "Couldn't read #{Pkg::Config.ref}.yaml, which is necessary for FOSS_ONLY. Retrieve cancelled."
    end
    platform_data = Pkg::Util::Serialization.load_yaml(yaml_path)[:platform_data]
    platform_data.each do |platform, paths|
      default_wget(local_target, "#{build_url}/artifacts/#{paths[:artifact]}") if Pkg::Config.foss_platforms.include?(platform)
    end
  end

  def retrieve_all(build_url, rsync_path, remote_target, local_target)
    if Pkg::Util::Tool.find_tool("wget")
      default_wget(local_target, "#{build_url}/#{remote_target}/")
    else
      warn "Could not find `wget` tool. Falling back to rsyncing from #{Pkg::Config.distribution_server}."
      begin
        Pkg::Util::Net.rsync_from("#{rsync_path}/#{remote_target}/", Pkg::Config.distribution_server, "#{local_target}/")
      rescue => e
        fail "Couldn't rsync packages from distribution server.\n#{e}"
      end
    end
  end
end
