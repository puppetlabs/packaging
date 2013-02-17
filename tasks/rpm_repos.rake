##
#
# A set of functionality for creating yum rpm repositories throughout the
# standard pkg/ directory layout that the packaging repo creates. The standard
# layout is:
# pkg/{el,fedora}/{5,6,f16,f17,f18}/{products,devel,dependencies,extras}/{i386,x86_64,SRPMS}
#
# Because we'll likely be creating the repos on a server that is remote, e.g.
# the distribution server, the logic here assumes we'll be doing everything via
# ssh commands.
#
namespace :pl do
  namespace :jenkins do
    desc "Create yum repositories of built RPM packages for this SHA on the distribution server"
    task :rpm_repos => ["pl:fetch", "pl:load_extras"] do
      # Formulate our command string, which will just find directories with rpms
      # and create and update repositories.
      #
      artifact_directory = File.join(@build.jenkins_repo_path, @build.project, git_sha.strip)

      ##
      # Test that the artifacts directory exists on the distribution server.
      # This will give us some more helpful output.
      #
      cmd = "echo \"Checking for build artifacts. Will exit if not found.\" ; "
      cmd << "[ -d #{artifact_directory}/artifacts ] || exit 0; "

      ##
      # Enter the directory containing the build artifacts and create repos.
      #
      cmd << "pushd #{artifact_directory} ; "
      cmd << "[ -d artifacts ] && rsync -avxl artifacts/ repos/ && pushd repos ; "
      cmd << "createrepo=$(which createrepo) ; "
      cmd << 'for repodir in $(find ./ -name "*.rpm" | xargs -I {} dirname {}) ; do '
      cmd << "pushd $repodir && $createrepo -d --update . && popd ; "
      cmd << "done"

      remote_ssh_cmd(@build.distribution_server, cmd)

    end
  end
end
