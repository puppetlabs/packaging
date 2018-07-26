require 'releng_metadata'
module Pkg
  module Metadata
    module_function

    def retrieve_metadata_section(section, catalog = nil)
      puts "Beginning to attempt #{section} metadata retrieval . . ."
      artifactory = RelengMetadata::Artifactory.new
      catalog ||= artifactory.most_recent_catalog
      puts "Retrieving #{section} metadata from catalog #{catalog} . . ."
      artifactory.fetch(catalog, section)
    end

    def retrieve_project_metadata(project, catalog = nil)
      puts "Beginning to attempt #{project} metadata retrieval . . ."
      artifactory = RelengMetadata::Artifactory.new
      catalog ||= artifactory.most_recent_catalog
      puts "Retrieving #{project} metadata from catalog #{catalog} . . ."
      artifactory.fetch(catalog, 'projects', project)
    end
  end
end
