# Utilities for working with rpm repos

module Pkg::Rpm::Repo
  class << self

    def ship_repo_configs
      Pkg::Util::File.empty_dir?("pkg/repo_configs/rpm") and fail "No repo configs have been generated! Try pl:rpm_repo_configs."
      invoke_task("pl:fetch")
      repo_dir = "#{Pkg::Config.jenkins_repo_path}/#{Pkg::Config.project}/#{Pkg::Config.ref}/repo_configs/rpm"
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.distribution_server, "mkdir -p #{repo_dir}")
      retry_on_fail(:times => 3) do
        Pkg::Util::Net.rsync_to("pkg/repo_configs/rpm/", Pkg::Config.distribution_server, repo_dir)
      end
    end

    def create_repos(directory = "repos")
      Dir.chdir(directory) do
        createrepo = Pkg::Util::Tool.find_tool('createrepo')
        cmd = 'for repodir in $(find ./ -name "*.rpm" | xargs -I {} dirname {}) ; do '
        cmd << "[ -d ${repodir} ] || continue; "
        cmd << "pushd ${repodir} && #{createrepo} --checksum=sha --database --update . ; popd ; "
        cmd << "done ; popd "
      end
    end
  end
end
