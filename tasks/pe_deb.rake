# "Alias" tasks for PE - these just point at the standard pl: tasks. They exist
# for ease of aggregation with PE-specific tasks that _are_ actually different
# from their "pl" counterparts
if @build.build_pe
  namespace :pe do
    desc "Create a PE deb from this repo using the default cow #{@build.default_cow}."
    task :deb => "pl:deb"

    desc "Create PE debs from this git repository using all cows specified in build_defaults yaml"
    task :deb_all => "pl:deb_all"
  end
end
