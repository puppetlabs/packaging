if @build_pe
  namespace :pe do
    desc "Create a PE deb from this repo using the default cow #{@default_cow}."
    task :local_deb => "pl:deb"

    desc "Create PE debs from this git repository using all cows specified in build_defaults yaml"
    task :local_deb_all => "pl:deb_all"
  end
end
