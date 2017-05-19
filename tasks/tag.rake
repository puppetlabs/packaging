namespace 'pl' do
  desc "Tag this repository, requires a TAG, e.g. TAG=1.1.1"
  task "tag" do
    Pkg::Util.check_var('TAG', ENV['TAG'])
    Pkg::Util::Git.tag(ENV['TAG'])
  end
end

