# Utility methods used to interface with the build manager

MANAGER_TIMEOUT=1800 # 30 minutes (in seconds)

def begin_managed_build(count, downstream, status)
  args = [
  "-Fname=#{@build.job_id}",
  "-Fcount=#{count}",
  "-Fdownstream=#{downstream}",
  "-Fstatus=#{status}",
  "-Ftimeout=#{MANAGER_TIMEOUT}",
  "-Fsha=#{@build.ref}",
  ]

  begin
    curl_form_data("#{@build.management_server}/create", args)
  rescue 
    fail "Could not contact the build manager."
  end
end

def post_managed_result status
  args = [
  "-Fname=#{@build.job_id}",
  "-Fstatus=#{status}"
  ]

  begin
    curl_form_data("#{@build.management_server}/checkin", args)
  rescue
    fail "Could not contact the build manager."
  end
end

def manageable_task(*args, &block)
  body = proc do
    status = :success
    begin
      block.call
    rescue
      status = :failure
      raise
    ensure
      post_managed_result(status) if @build.managed
    end
  end
  Rake::Task.define_task(*args, &body)
end

# Having a block that returns the number of sub-jobs isn't the most
# intuitve API in the world, but it seriously cuts down on the
# duplicate code.
def make_managed_task(task, &count_block)
  body = proc do
    downstream_job = ENV["DOWNSTREAM_JOB"]
    status_job = ENV["STATUS_JOB"]
    build_count = count_block.call

    check_var("DOWNSTREAM_JOB", downstream_job)
    check_var("STATUS_JOB", status_job)

    # Make sure managed build info gets passed on to the
    # downstream jobs
    @build.job_id = random_string(64)
    @build.managed = true
    
    # Pull DOWNSTREAM_JOB out of the environment. We want to pass
    # it on to the build manager, but not to the individual jobs
    # (they will check in to the build manager)
    ENV["DOWNSTREAM_JOB"] = nil

    begin_managed_build(build_count, downstream_job, status_job)
    invoke_task("#{@build.build_pe ? "pe" : "pl"}:jenkins:#{task}")
  end
  Rake::Task.define_task("managed_#{task}".to_sym, &body)
end
