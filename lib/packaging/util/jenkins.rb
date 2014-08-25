# Utility methods for handling Jenkins

module Pkg::Util::Jenkins

  class << self

    # Use the curl to create a jenkins job from a valid XML
    # configuration file.
    # Returns the URL to the job
    def create_jenkins_job(name, xml_file)
      create_url = "http://#{Pkg::Config.jenkins_build_host}/createItem?name=#{name}"
      form_args = ["-H", '"Content-Type: application/xml"', "--data-binary", "@#{xml_file}"]
      Pkg::Util::Net.curl_form_data(create_url, form_args)
      "http://#{Pkg::Config.jenkins_build_host}/job/#{name}"
    end

    # Use the curl to check of a named job is defined on the jenkins server.  We
    # curl the config file rather than just checking if the job exists by curling
    # the job url and passing --head because jenkins will mistakenly return 200 OK
    # if you issue multiple very fast requests just requesting the header.
    def jenkins_job_exists?(name)
      job_url = "http://#{Pkg::Config.jenkins_build_host}/job/#{name}/config.xml"
      form_args = ["--silent", "--fail"]
      Pkg::Util::Net.curl_form_data(job_url, form_args, :quiet => true)
    end
  end
end
