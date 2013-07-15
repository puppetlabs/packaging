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
    task :uber_build => "pl:fetch" do
      # If we have a dirty source, bail, because changes won't get reflected in
      # the package builds
      fail_on_dirty_source

      # Use JSON to parse the json part of the submission, so we want to fail
      # here also if JSON isn't available
      require_library_or_fail 'json'

      # The uber_build.xml.erb file is an XML erb template that will define a
      # job in Jenkins with all of the appropriate tasks
      work_dir           = get_temp
      template_dir       = File.join(File.dirname(__FILE__), '..', 'templates')
      templates          = ['repo.xml.erb', 'packaging.xml.erb']
      templates.unshift('downstream.xml.erb') if ENV['DOWNSTREAM_JOB']

      # Generate an XML file for every job configuration erb and attempt to
      # create a jenkins job from that XML config
      templates.each do |t|
        erb_file  = File.join(template_dir, t)
        xml_file = File.join(work_dir, t.gsub('.erb', ''))
        erb(erb_file, xml_file)
        job_name  = "#{@build.project}-#{t.gsub('.xml.erb','')}-#{@build.build_date}-#{@build.ref}"
        puts "Checking for existence of #{job_name}..."
        if jenkins_job_exists?(job_name)
          raise "Job #{job_name} already exists on #{@build.jenkins_build_host}"
        else
          url = create_jenkins_job(job_name, xml_file)
          puts "Jenkins job created at #{url}"
        end
      end
      rm_r work_dir
      packaging_name = "#{@build.project}-packaging-#{@build.build_date}-#{@build.ref}"
      invoke_task("pl:jenkins:trigger_dynamic_job", packaging_name)
    end

    # Task to trigger the jenkins job we just created. This uses a lot of the
    # same logic in jenkins.rake, with different parameters.
    # TODO make all this replicated code a better, more abstract method
    task :trigger_dynamic_job, :name do |t, args|
      name = args.name

      properties = @build.params_to_yaml
      bundle = git_bundle('HEAD')

      # Construct the parameters, which is an array of hashes we turn into JSON
      parameters = [{ "name" => "BUILD_PROPERTIES", "file"  => "file0" },
                    { "name" => "PROJECT_BUNDLE",   "file"  => "file1" },
                    { "name" => "PROJECT",          "value" => "#{@build.project}" }]

      # Contruct the json string
      json = JSON.generate("parameter" => parameters)

      # The args array that holds  all of the arguments we pass
      # to the curl utility method.
      curl_args =  [
      "-Fname=BUILD_PROPERTIES", "-Ffile0=@#{properties}",
      "-Fname=PROJECT_BUNDLE"  , "-Ffile1=@#{bundle}",
      "-Fname=PROJECT"         , "-Fvalue=#{@build.project}",
      "-FSubmit=Build",
      "-Fjson=#{json.to_json}",
      ]

      # Contstruct the job url
      trigger_url = "#{@build.jenkins_build_host}/job/#{name}/build"

      if curl_form_data(trigger_url, curl_args)
        print_url_info("#{@build.jenkins_build_host}/job/#{name}")
        puts "Your packages will be available at #{@build.distribution_server}:#{@build.jenkins_repo_path}/#{@build.project}/#{@build.ref}"
      else
        warn "An error occurred submitting the job to jenkins. Take a look at the preceding http response for more info."
      end

      # Clean up after ourselves
      rm bundle
      rm properties
    end
  end
end

