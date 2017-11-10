##
# This task is intended to retrieve packages from the distribution server that
# have been built by jenkins and placed in a specific location,
# /opt/jenkins-builds/$PROJECT/$SHA where $PROJECT is the build project as
# established in build_defaults.yaml and $SHA is the git sha/tag of the project that
# was built into packages. The current day is assumed, but an environment
# variable override exists to retrieve packages from another day. The sha/tag is
# assumed to be the current project's HEAD, e.g.  to retrieve packages for a
# release of 3.1.0, checkout 3.1.0 locally before retrieving.
#

namespace :pl do
  namespace :jenkins do
    desc "Retrieve packages from the distribution server\. Check out commit to retrieve"
    task :retrieve, :remote_target, :local_target do |t, args|
      remote_target = args.remote_target || "artifacts"
      local_target = args.local_target || "pkg"
      Pkg::Util::RakeUtils.invoke_task("pl:fetch")
      mkdir_p local_target
      package_url = "http://#{Pkg::Config.builds_server}/#{Pkg::Config.project}/#{Pkg::Config.ref}"
      if wget = Pkg::Util::Tool.find_tool("wget")
        if Pkg::Config.foss_only && !Pkg::Config.foss_platforms
          warn "FOSS_ONLY specified, but I don't know anything about FOSS_PLATFORMS. Fetch everything?"
          unless Pkg::Util.ask_yes_or_no(true)
            warn "Retrieve cancelled"
            exit
          end
        elsif Pkg::Config.foss_only && !(remote_target == 'artifacts' || remote_target == 'repos')
          warn "I only know how to fetch from remote_target 'artifacts' or 'repos' with FOSS_ONLY. Fetch everything?"
          unless Pkg::Util.ask_yes_or_no(true)
            warn "Retrieve cancelled"
            exit
          end
        end
        if Pkg::Config.foss_only
          # Grab the <ref>.yaml file
          sh "#{wget} --quiet --recursive --no-parent --no-host-directories --level=0 --cut-dirs 3 --directory-prefix=#{local_target} #{package_url}/#{remote_target}/#{Pkg::Config.ref}.yaml"
          yaml_path = File.join(local_target, "#{Pkg::Config.ref}.yaml")
          unless File.readable?(yaml_path)
            fail "Couldn't read #{Pkg::Config.ref}.yaml, which is necessary for FOSS_ONLY. Retrieve cancelled"
          end
          platform_data = Pkg::Util::Serialization.load_yaml(yaml_path)[:platform_data]
          platform_data.each do |platform, paths|
            sh "#{wget} --quiet --recursive --no-parent --no-host-directories --level=0 --cut-dirs 3 --directory-prefix=#{local_target} --reject 'index*' #{package_url}/#{remote_target}/#{paths[:artifact]}" if Pkg::Config.foss_platforms.include?(platform)
          end
        else
          sh "#{wget} --quiet --recursive --no-parent --no-host-directories --level=0 --cut-dirs 3 --directory-prefix=#{local_target} --reject 'index*' #{package_url}/#{remote_target}/"
        end
      else
        warn "Could not find `wget` tool. Falling back to rsyncing from #{Pkg::Config.distribution_server} and attempting to retrieve everything."
        begin
          Pkg::Util::Net.rsync_from("#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/#{remote_target}/", Pkg::Config.distribution_server, "#{local_target}/")
        rescue => e
          fail "Couldn't download packages from distribution server.\n#{e}"
        end
      end
      puts "Packages staged in #{local_target}"
    end
  end
end

if Pkg::Config.build_pe
  namespace :pe do
    namespace :jenkins do
      desc "Retrieve packages from the distribution server\. Check out commit to retrieve"
      task :retrieve, :target do |t, args|
        target = args.target || "artifacts"
        Pkg::Util::RakeUtils.invoke_task("pl:jenkins:retrieve", target)
      end
    end
  end
end
