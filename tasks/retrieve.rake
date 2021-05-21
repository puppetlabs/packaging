##
# This task is intended to retrieve packages from the distribution server that
# have been built by jenkins and placed in a specific location,
# /opt/jenkins-builds/$PROJECT/$SHA where $PROJECT is the build project as
# established in build_defaults.yaml and $SHA is the git sha/tag of the project that
# was built into packages. The current day is assumed, but an environment
# variable override exists to retrieve packages from another day. The sha/tag is
# assumed to be the current project's HEAD, e.g.  to retrieve packages for a
# release of 3.1.0, checkout 3.1.0 locally before retrieving.
#


namespace :pl do
  namespace :jenkins do
    desc "Retrieve packages from the distribution server. Check out commit to retrieve"
    task :retrieve, [:remote_target, :local_target] => 'pl:fetch' do |t, args|
      remote_target = args.remote_target || 'artifacts'
      local_target = args.local_target || 'pkg'

      Pkg::Retrieve.retrieve(remote_target, local_target)
    end 
  end
end

if Pkg::Config.build_pe
  namespace :pe do
    namespace :jenkins do
      desc "Retrieve packages from the distribution server. Check out commit to retrieve"
      task :retrieve, [:remote_target, :local_target] => 'pl:fetch' do |t, args|
        remote_target = args.remote_target || 'artifacts'
        local_target = args.local_target || 'pkg'

        Pkg::Retrieve.retrieve_pe(remote_target, local_target)
      end
    end
  end
end

