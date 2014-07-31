##
# Create a debian repository under the standard pkg/ directory layout that the
# packaging repo creates. The standard layout is pkg/deb/$distribution/files.
# The repository is created in the 'repos' directory under the jenkins build
# directories on the distribution server, e.g.
# /opt/jenkins-builds/$project/$sha/repos. Because we're creating deb
# repositories on the fly, we have to generate the configuration files as well.
# We assume every directory under the `deb` directory is named for a
# distribution, and we use this in creating our configurations.
#
namespace :pl do
  namespace :jenkins do
    desc "Create apt repositories of build DEB packages for this SHA on the distributions erver"
    task :deb_repos => "pl:fetch" do
      Pkg::Deb::Repo.create_repos
    end

    desc "Create apt repository configs for package repos for this sha/tag on the distribution server"
    task :generate_deb_repo_configs => "pl:fetch" do
      Pkg::Deb::Repo.generate_repo_configs
    end

    desc "Retrieve debian apt repository configs for this sha"
    task :deb_repo_configs => "pl:fetch" do
      Pkg::Deb::Repo::retrieve_repo_configs
    end
  end
end
