# Rake Task to dynamically create a Jenkins job to model the
# pl:jenkins:uber_build set of tasks in a Matrix job where each cell is an
# individual build to be run.
namespace :pl do
  namespace :jenkins do
    desc "Dynamic Jenkins UBER build: Build all the things with ONE job"
    task :uber_build_dynamic do
      # The uber_build.xml.erb file is an XML erb template that will define a
      # job in Jenkins with all of the appropriate tasks
      work_dir = get_temp
      template = File.join('..', 'templates', 'uber_build.xml.erb')
      xml_file = File.join(work_dir, 'uber_build.xml')
      xml = IO.read(erb(template, xml))
      create_jenkins_job("#{@build.project}-#{random_string 32}", xml)
    end
  end
end

