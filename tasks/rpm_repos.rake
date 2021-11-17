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
    # The equivalent to invoking this task is calling Pkg::Util::Repo.rpm_repos
    desc "Create yum repositories of built RPM packages for this SHA on the distribution server"
    task :rpm_repos => "pl:fetch" do
      Pkg::Rpm::Repo.create_remote_repos
    end

    desc "Create yum repository configs for package repos for this sha/tag on the distribution server"
    task :generate_rpm_repo_configs => "pl:fetch" do
      Pkg::Rpm::Repo.generate_repo_configs
    end

    desc "Retrieve rpm yum repository configs from distribution server"
    task :rpm_repo_configs => "pl:fetch" do
      Pkg::Rpm::Repo.retrieve_repo_configs
    end
  end
end
