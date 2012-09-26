namespace 'pl' do
  desc "Tag this repository, requires a TAG, e.g. TAG=1.1.1"
  task "tag" do
    check_var('TAG', ENV['TAG'])
    git_tag(ENV['TAG'])
  end
end

