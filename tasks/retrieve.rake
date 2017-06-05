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
        ## The following logic has been temporarily removed as FOSS_ONLY
        ## expects a specific path structure that we are currently changing.
        ## This will be fixed shortly, but for now we will fail if FOSS_ONLY
        ## is specified.
        ##
        if Pkg::Config.foss_only
          fail "FOSS_ONLY is temporarily unsupported. You must fetch everything and remove PE-only platforms from pkg/."
        ##if Pkg::Config.foss_only && !Pkg::Config.foss_platforms
        ##  warn "FOSS_ONLY specified, but I don't know anything about FOSS_PLATFORMS. Fetch everything?"
        ##  unless Pkg::Util.ask_yes_or_no(true)
        ##    warn "Retrieve cancelled"
        ##    exit
        ##  end
        ##elsif Pkg::Config.foss_only && remote_target != 'artifacts'
        ##  warn "I only know how to fetch from remote_target 'artifacts' with FOSS_ONLY. Fetch everything?"
        ##  unless Pkg::Util.ask_yes_or_no(true)
        ##    warn "Retrieve cancelled"
        ##    exit
        ##  end
        ##end
        ##if Pkg::Config.foss_only && Pkg::Config.foss_platforms && remote_target == 'artifacts'
        ##  Pkg::Config.foss_platforms.each do |platform|
        ##    begin
        ##      platform_path = Pkg::Paths.artifacts_path(platform, package_url)
        ##      _, _, arch = Pkg::Platforms.parse_platform_tag(platform)
        ##      url = "#{package_url}/#{platform_path}"
        ##      puts "Fetching: Platform = #{platform}, URL = #{url}"
        ##      #osx packages have no platform in their name
        ##      if platform =~ /^osx/
        ##        sh "#{wget} --quiet -r -np -nH -l 0 --cut-dirs 3 -P #{local_target} --reject 'index*' #{url}/"
        ##      else
        ##        sh "#{wget} --quiet -r -np -nH -l 0 --cut-dirs 3 -P #{local_target} --reject 'index*' --accept '*#{arch}*' #{url}/"
        ##      end
        ##    rescue => e
        ##      warn "Encountered error fetching #{platform}:"
        ##      warn e
        ##    end
        ##  end

        ##  # also want to fetch the yaml and the signing bundle
        ##  sh "#{wget} --quiet -r -np -nH -l 0 --cut-dirs 3 -P #{local_target} --reject 'index*' --accept '*.yaml' #{package_url}/#{remote_target}/"
        ##  sh "#{wget} --quiet -r -np -nH -l 0 --cut-dirs 3 -P #{local_target} --reject 'index*' --accept '*.tar.gz' #{package_url}/#{remote_target}/"

        ##  # Recursively remove empty directories under pkg
        ##  Dir.glob("#{local_target}/**/*").select { |f| File.directory? f }.sort.uniq.reverse.each do |path|
        ##    if Dir["#{path}/*"].empty?
        ##      Dir.delete "#{path}"
        ##    end
        ##  end
        else
          # For the next person who needs to look these flags up:
          # -r = recursive
          # -l 0 = infinitely recurse, no limit
          # --cut-dirs 3 = will cut off #{Pkg::Config.project}, #{Pkg::Config.ref}, and the first directory in #{remote_target} from the url when saving to disk
          # -np = Only descend when recursing, never ascend
          # -nH = Discard http://#{Pkg::Config.builds_server} when saving to disk
          # --reject = Reject all hits that match the supplied regex
          # -P = where to save to disk (defaults to ./)
          sh "#{wget} --quiet -r -np -nH -l 0 --cut-dirs 3 -P #{local_target} --reject 'index*' #{package_url}/#{remote_target}/"
        end
      else
        warn "Could not find `wget` tool. Falling back to rsyncing from #{Pkg::Config.distribution_server}"
        begin
          Pkg::Util::Net.rsync_from("#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/#{remote_target}/", Pkg::Config.distribution_server, "#{local_target}/")
        rescue => e
          fail "Couldn't download packages from distribution server.\n#{e}"
        end
      end
      puts "Packages staged in pkg"
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
