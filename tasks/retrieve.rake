##
# This task is intended to retrieve packages from the distribution server that
# have been built by jenkins and placed in a specific location,
# /opt/jenkins-builds/$PROJECT/$SHA where $PROJECT is the build project as
# established in project_data.yaml and $SHA is the git sha of the project that
# was built into packages. The current day is assumed, but an environment
# variable override exists to retrieve packages from another day. The sha is
# assumed to be the current project's HEAD, e.g.  to retrieve packages for a
# release of 3.1.0, checkout 3.1.0 locally before retrieving.
#

namespace :pl do
  namespace :jenkins do
    desc "Retrieve packages from the distribution server\. Check out commit to retrieve"
    task :retrieve, :target do |t, args|
      target = args.target || "artifacts"
      ["pl:fetch", "pl:load_extras" ].each { |t| invoke_task(t) }
      mkdir_p 'pkg'
      rsync_from("#{@build.jenkins_repo_path}/#{@build.project}/#{git_sha.strip}/#{target}/", @build.distribution_server, "pkg/")
      puts "Packages staged in pkg"
    end
  end
end
