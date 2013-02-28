# For PE, the natural default tasks are the remote tasks, rather than
# the local ones, in reflection of which will be most ideal for PE devs.
# e.g., pe:local_deb is the task to build a deb on the local host,
# while pe:deb is the task for building on the remote builder host

if @build.build_pe
  namespace :pe do
    desc "Create a PE deb from this repo using the default cow #{@build.default_cow}."
    task :local_deb => "pl:deb"

    desc "Create PE debs from this git repository using all cows specified in build_defaults yaml"
    task :local_deb_all => "pl:deb_all"
  end
end
