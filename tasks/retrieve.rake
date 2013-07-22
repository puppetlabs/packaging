##
# This task is intended to retrieve packages from the distribution server that
# have been built by jenkins and placed in a specific location,
# /opt/jenkins-builds/$PROJECT/$SHA where $PROJECT is the build project as
# established in project_data.yaml and $SHA is the git sha/tag of the project that
# was built into packages. The current day is assumed, but an environment
# variable override exists to retrieve packages from another day. The sha/tag is
# assumed to be the current project's HEAD, e.g.  to retrieve packages for a
# release of 3.1.0, checkout 3.1.0 locally before retrieving.
#

namespace :pl do
  namespace :jenkins do
    desc "Retrieve packages from the distribution server\. Check out commit to retrieve"
    task :retrieve, :target do |t, args|
      target = args.target || "artifacts"
      invoke_task("pl:fetch")
      mkdir_p 'pkg'
      package_url = "http://#{@build.builds_server}/#{@build.project}/#{@build.ref}/#{target}"
      if wget=find_tool("wget")
        sh "#{wget} -r -np -nH --cut-dirs 3 -P pkg --reject 'index*' #{package_url}/"
      else
        warn "Could not find `wget` tool. Falling back to rsyncing from #{@build.distribution_server}"
        begin
          rsync_from("#{@build.jenkins_repo_path}/#{@build.project}/#{@build.ref}/#{target}/", @build.distribution_server, "pkg/")
        rescue
          fail "Couldn't download packages from distribution server. Try installing wget!"
        end
      end
      puts "Packages staged in pkg"
    end
  end
end
