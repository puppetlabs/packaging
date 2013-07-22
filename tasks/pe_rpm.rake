if @build.build_pe
  namespace :pe do
    desc "Build a PE rpm using rpmbuild (requires all BuildRequires, rpmbuild, etc)"
    task :rpm => "package:rpm"

    desc "Build rpms using ALL final mocks in build_defaults yaml, keyed to PL infrastructure, pass MOCK to override"
    task :mock_all => ["pl:fetch", "pl:mock_all"]

    desc "Build a PE rpm using the default mock"
    task :mock => ["pl:fetch", "pl:mock"]
  end
end

