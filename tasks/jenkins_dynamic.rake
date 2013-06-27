# Rake Task to dynamically create a Jenkins job to model the
# pl:jenkins:uber_build set of tasks in a Matrix job where each cell is an
# individual build to be run.
namespace :pl do
  namespace :jenkins do
    desc "Dynamic Jenkins UBER build: Build all the things with ONE job"
    task :uber_build_dynamic => "pl:fetch" do
      # The uber_build.xml.erb file is an XML erb template that will define a
      # job in Jenkins with all of the appropriate tasks
      work_dir = get_temp
      template = File.join(File.dirname(__FILE__), '..', 'templates', 'uber_build.xml.erb')
      xml_file = File.join(work_dir, 'uber_build.xml')
      erb(template, xml_file)
      xml = IO.read(xml_file)
      job_name = "#{@build.project}-#{timestamp('-')}-#{@build.ref}"
      if jenkins_job_exists?(job_name)
        raise "Job #{job_name} already exists on #{@build.jenkins_build_server}"
      else
        url = create_jenkins_job(job_name, xml)
        puts "Jenkins job created at #{url}"
      end
    end
  end
end

