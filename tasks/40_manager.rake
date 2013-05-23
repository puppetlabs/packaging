# Utility methods used to interface with the build manager

module TaskOrchestration

  class BuildManager

    TIMEOUT=1800 # 30 minutes (in seconds)

    attr_accessor :job_id, :timeout, :ref, :downstream_job, :status_job, :server

    def initialize
      @timeout = TIMEOUT
      yield self if block_given?
    end

    # Post to the management server to notify of a pending build
    def post_managed_build_start(status_job, task_count)
      curl_args = [
      "-Fname=#{@job_id}",
      "-Fcount=#{task_count}",
      "-Fdownstream=#{@downstream_job}",
      "-Fstatus=#{status_job}",
      "-Ftimeout=#{@timeout}",
      "-Fsha=#{@ref}",
      ]

      begin
        curl_form_data("#{@server}/checkin", curl_args)
      rescue
        fail "Could not contact the build manager."
      end
    end

    # Post to the build server with a status
    # Expects hash of args with
    # :job_id            => (unique id tracking this job group)
    # :status            => (the job's completion status)
    def post_managed_build_result(status)
      curl_args = [
      "-Fname=#{@job_id}",
      "-Fstatus=#{status}"
      ]

      begin
        curl_form_data("#{@server}/checkin", curl_args)
      rescue
        fail "Could not contact the build manager."
      end
    end
  end
end
