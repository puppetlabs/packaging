
# Modify existing Rake tasks with behavior to support managed builds Use
# monkey-patched #unshift method and existing #enhance method to enable
# inserting actions into already defined rake tasks on the fly.

# For core tasks (e.g. pl:deb, package:tar, etc) we use #enhance to add an
# additional execution block after the existing tasks, containing a status post
# to the build server. Each individual task (e.g. deb cow build) has to post a
# status, which is why we're adding at this level.

# For aggregate-style tasks, e.g. "pl:deb_all" we prepend to the existing
# execution blocks with one which notifies the build manager that a build has
# started. This means that only these specific tasks we're working with here
# are capable of this.

if @build.managed
  unless @build.management_server
    fail "
You set 'managed build' to true but have not supplied a management server via the 'management_server' key in project_data.yaml or by passing MANAGEMENT_SERVER=<server> to rake"
  end

  downstream_job = check_var("DOWNSTREAM_JOB=<url>", ENV['DOWNSTREAM_JOB'])
  status_job = check_var("STATUS_JOB=<url>", ENV['STATUS_JOB'])

  @build.job_id ||= random_string(64)
  manager = TaskOrchestration::BuildManager.new do |m|
    m.job_id = @build.job_id
    m.ref = @build.ref
    m.server = @build.management_server
    m.downstream_job = downstream_job
  end

  # These are the "core" tasks, the tasks that are managed as components of
  # larger aggregate tasks.
  core_managed_task_names = ["package:tar", "package:gem", "pl:deb", "pl:mock", "pl:dmg"]

  core_managed_task_names.each do |name|
    task = RakeUtils.find_task(name.to_s)

    # Append the status post to the server to the list of execution blocks
    task.enhance do
      manager.post_managed_build_result(:success)
    end
  end

  # The :uber_builds are the aggregate tasks, ones that are composed of many,
  # many core_managed_task calls. Before these begin their work we want to
  # notify the build manager of an impending managed build, so we insert a new
  # execution block to do so.
  aggregate_managed_task_names = ["pl:jenkins:uber_build", "pe:jenkins:uber_build"]

  aggregate_managed_task_names.each do |name|
    task = RakeUtils.find_task(name.to_s)

    # Insert the managed build trigger before the existing execution blocks
    task.unshift do
      manager.post_managed_build_start(status_job)
    end
  end

  # Because we're using the Build Manager to trigger the downstream job, we
  # have to pull it out of the environment here, or jenkins will try to trigger
  # it as part of the standard asynchronous jenkins workflow.
  ENV['DOWNSTREAM_JOB'] = nil
end

