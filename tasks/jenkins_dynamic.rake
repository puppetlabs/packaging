# Rake Task to dynamically create a Jenkins job to model the
# pl:jenkins:uber_build set of tasks in a Matrix job where each cell is an
# individual build to be run. This would be nice if we only had to create one job,
# but alas, we're actually creating three jobs.
# 1) a packaging job that builds the packages
#                     |
#                     V
# 2) a repo creation job that creates repos from those packages
#                     |
#                     V
# 3) (optional) a job to proxy the downstream job passed in via DOWNSTREAM_JOB
#

namespace :pl do
  namespace :jenkins do
    desc "Dynamic Jenkins UBER build: Build all the things with ONE job"
    task :uber_build_dynamic => "pl:fetch" do
      # The uber_build.xml.erb file is an XML erb template that will define a
      # job in Jenkins with all of the appropriate tasks
      @build.build_date  = timestamp('-')
      work_dir           = get_temp
      template_dir       = File.join(File.dirname(__FILE__), '..', 'templates')
      templates          = ['packaging.xml.erb', 'repo.xml.erb']
      templates          << 'downstream.xml.erb' if ENV['DOWNSTREAM_JOB']

      # Generate an XML file for every job configuration erb and attempt to
      # create a jenkins job from that XML config
      templates.each do |t|
        erb_file = File.join(template_dir, t)
        xml_file = File.join(work_dir, t.gsub('.erb', ''))
        erb(erb_file, xml_file)

        xml = IO.read(xml_file)

        job_name = "#{@build.project}-#{t.gsub('.xml.erb','')}-#{@build.build_date}-#{@build.ref}"
        if jenkins_job_exists?(job_name)
          raise "Job #{job_name} already exists on #{@build.jenkins_build_server}"
        else
          url = create_jenkins_job(job_name, xml)
          puts "Jenkins job created at #{url}"
        end
      end
      rm_r work_dir
    end
  end
end

