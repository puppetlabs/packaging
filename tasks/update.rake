namespace :package do
  desc "Update your clone of the packaging repo with `git pull`"
  task :update do
    cd 'ext/packaging' do
      remote = @build.packaging_url.split(' ')[0]
      branch = @build.packaging_url.split(' ')[1].split('=')[1]
      if branch.nil? or remote.nil?
        STDERR.puts "Couldn't parse the packaging repo URL from 'ext/build_defaults.yaml'."
        STDERR.puts "Normally this is a string in the format git@github.com:<User>/<packaging_repo> --branch=<branch>"
      else
        git_pull(remote, branch)
      end
    end
  end
end

