namespace :package do
  desc "Update your clone of the packaging repo with `git pull`"
  task :update do
    cd 'ext/packaging' do
      remote = Pkg::Config.packaging_url.split(' ')[0]
      branch = Pkg::Config.packaging_url.split(' ')[1].split('=')[1]
      if branch.nil? or remote.nil?
        $stderr.puts "Couldn't parse the packaging repo URL from 'ext/build_defaults.yaml'."
        $stderr.puts "Normally this is a string in the format git@github.com:<User>/<packaging_repo> --branch=<branch>"
      else
        Pkg::Util::Git.pull(remote, branch)
      end
    end
  end
end

