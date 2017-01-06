# Utility methods for handling Jenkins
require 'net/http'
require 'json'

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
      output, retval = Pkg::Util::Net.curl_form_data(job_url, form_args, :quiet => true)
      return output if retval.nil?
      return Pkg::Util::Execution.success?(retval)
    end

    # Wait for last build of job to finish.
    #
    # @param build_url [String] Valid build uri of a Jenkins job.
    # @param polling_interval [Int] Timeout in seconds between HTTP GET on given
    #                               build_uri.
    # @param log_frequency [Int] Frequency in seconds of polling log
    #
    def wait_for_build(build_url, polling_interval = 2, log_frequency = 60)
      $stdout.sync = true
      build_hash = get_jenkins_info(build_url)
      total_time = 0
      while build_hash['building']
        build_hash = get_jenkins_info(build_url)
        sleep polling_interval
        total_time += polling_interval
        if total_time >= log_frequency
          $stdout.puts "Polling #{build_url}..."
          total_time = 0
        end
      end
      $stdout.sync = false
      return build_hash
    end

    # Query jenkins api and return a hash parsed from the JSON response if
    # response is usable. Raise Runtime Error if response code is other than
    # HTTP 200.
    #
    # @param url [String] Valid url of a Jenkins job.
    #
    def get_jenkins_info(url)
      uri = URI("#{url}/api/json")
      response = Net::HTTP.get_response(uri)
      unless response.code == '200'
        raise "Unable to query #{uri}, please check that it is valid."
      end
      return JSON.parse(response.body)
    end

    # Poll the job at the given url until it is finished, then return the final
    # map of build information for calling context to do with as it pleases.
    #
    # Note that this method uses the build specified by the job api's lastBuild
    # parameter.
    #
    # @param job_url [String] Valid url of a Jenkins job.
    #
    def poll_jenkins_job(job_url)
      job_hash = get_jenkins_info(job_url)

      ##
      # Sometimes we get a nil because we get here too soon after the jenkins
      # job's build was triggered. This is kind of an ugly workaround but
      # whatever.
      #
      while job_hash['lastBuild'].nil?
        job_hash = get_jenkins_info(job_url)
        sleep 1
      end

      wait_for_build job_hash['lastBuild']['url']
    end

  end
end
