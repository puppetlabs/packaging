##
# The jenkins tasks enable the packaging repo to kick off packaging builds on a
# remote jenkins slave. They work in a similar way to the :remote tasks, but
# with a few key differences. The jenkins tasks transmit information to a
# jenkins coordinator, which handles the rest. The data passed are the
# following:
#
# 1) $PROJECT_BUNDLE - a tar.gz of a git-bundle from HEAD of the current
#    project, which is cloned on the builder to set up a duplicate of this
#    environment
#
# 2) $BUILD_PROPERTIES - a build parameters file, containing all information about the build
#
# 3) $BUILD_TYPE - the "type" of build, e.g. rpm, deb, gem, etc The jenkins url and job name
#    are obtained via the team build-data file at
#    git@github.com/puppetlabs/build-data
#
# 4) $PROJECT - the project we're building, e.g. facter, puppet. This is used later in
#    determining the target for the build artifacts on the distribution server
#
# On the Jenkins end, the job is a parameterized job that accepts four
# parameters. Jenkins has the Parameterized Trigger Plugin, Workspace Cleanup
# Plugin, and Node and Label Parameter Plugin in use for this job. The
# workspace cleanup plugin cleans the workspace before each build. Two are file
# parameters, a string parameter, and a Label parameter provided by the Node
# and Label Parameter Plugin, as described above. When th pl:jenkins:post task
# triggers a build, it passes values for all of these parameters. The Label
# parameter is associated with the build type. This way we can queue the job on
# a builder with the appropriate capabilities just by assigning a builder the
# label "deb" or "rpm," etc. The actual build itself is accomplished via a
# shell build task. The contents of the task are:
#
#   # The build properties file is named $SHA.yaml where $SHA is the commit
#   # hash of the current build.
#   SHA=$(echo $BUILD_PROPERTIES | cut -d '.' -f1)
#
#   echo #############################
#   echo "Build type: $BUILD_TYPE"
#   echo #############################
#   ### Create a local clone of the git-bundle that was passed
#   # The bundle is a tarball, and since this is a project-agnostic
#   # job, we don't actually know what's in it, just that it's a
#   # git bundle.
#   #
#
#   [ -f "PROJECT_BUNDLE" ] || exit 1
#   mkdir project && tar -xzf PROJECT_BUNDLE -C project/
#
#   cd project
#   git clone --recursive $(ls) git_repo
#
#   cd git_repo
#
#   ### Clone the packaging repo
#   rake package:bootstrap && rake pl:fetch
#
#   ### Perform the build
#   rake pl:load_extras pl:build_from_params PARAMS_FILE=$WORKSPACE/BUILD_PROPERTIES
#
#   ### Create the results directory
#   ssh neptune.puppetlabs.lan "mkdir -p /opt/jenkins-builds/$PROJECT/$SHA"
#
#   ### Chgrp to appropriate users can immediately access and create subdirectories
#   ssh neptune.puppetlabs.lan "chgrp release /opt/jenkins-builds/$PROJECT/$SHA"
#
#   ### Send the results
#   rake pl:jenkins:ship
#
#   # Clean up
#   cd $WORKSPACE && rm -r *
#
##################

namespace :pl do
  namespace :jenkins do
    ##
    # Do the heavy lifting. This task generates the URL for the jenkins job and posts it.
    # It expects a the following arguments
    # 1. :build_task => The lower-level pl: or pe: task we're executing, e.g. pl:deb_all
    #
    task :post, :build_task do |t, args|
      # We use JSON for parsing the json part of the submission to JSON
      begin
        require 'json'
      rescue LoadError
        warn "Couldn't require 'json'. JSON is required for sanely generating the string we curl to Jenkins."
        exit 1
      end

      unless curl = find_tool('curl')
        warn "curl is required for posting to jenkins to trigger a build. Please install curl and try again."
        exit 1
      end
      build_task = args.build_task
      ##
      # We set @:task of @build manually with our task data so the remote
      # build knows what to do. Puppetdb needs early knowledge of if this is
      # a PE build, so we always this along as an environment variable task
      # argument if its the case.
      #
      @build.task = ["#{build_task}"]
      @build.task << "PE_BUILD=true" if @build_pe
      #
      # Determine the type of build we're doing to inform jenkins
      build_type = case build_task
        when /deb/ then "deb"
        when /mock/ then "rpm"
        when /dmg|apple/ then "dmg"
        when /gem/ then "gem"
        when /tar/ then "tar"
        when /sles/ then "sles"
        else raise "Could not determine build type for #{build_task}"
      end
      #
      # Create the data files to send to jenkins
      properties = @build.params_to_yaml
      bundle = git_bundle('HEAD')

      # Contruct the json string
      json = JSON.generate("parameter" => [{ "name" => "BUILD_PROPERTIES", "file"  => "file0" },
                                           { "name" => "PROJECT_BUNDLE",   "file"  => "file1" },
                                           { "name" => "PROJECT",          "value" => "#{@build.project}" },
                                           { "name" => "BUILD_TYPE",       "label" => "#{build_type}" },])

      # Construct the form arguments. For visual clarity, params that are tied
      # together are on the same line.
      #
      args =  [
      "-Fname=BUILD_PROPERTIES", "-Ffile0=@#{properties}",
      "-Fname=PROJECT_BUNDLE"   , "-Ffile1=@#{bundle}",
      "-Fname=PROJECT"          , "-Fvalue=#{@build.project}",
      "-Fname=BUILD_TYPE"       , "-Fvalue=#{build_type}",
      "-FSubmit=Build",
      "-Fjson=#{json.to_json}",
      ]


      # Construct the job url
      #
      job_url = "#{@build.jenkins_build_host}/job/#{@build.jenkins_packaging_job}"
      trigger_url = "#{job_url}/build"

      # Call out to the curl_form_data utility method in 00_utils.rake
      #
      if curl_form_data(trigger_url, args)
        puts "Build submitted. To view your build results, go to #{job_url}"
        puts "Your packages will be available at #{@build.distribution_server}:#{@build.jenkins_repo_path}/#{@build.project}/#{git_sha}"
      else
        warn "An error occurred submitting the job to jenkins. Take a look at the preceding http response for more info."
      end
    end
  end
end

##
# A task listing for creating jenkins tasks for our various pl: and pe: build
# tasks. We can assume deb, mock, but not gem/dmg.
#
tasks = ["deb", "deb_all", "mock", "mock_all", "tar"]
tasks << "gem" if @build.build_gem and ! @build.build_pe
tasks << "dmg" if @build.build_dmg and ! @build.build_pe

namespace :pl do
  namespace :jenkins do
    tasks.each do |build_task|
      desc "Queue pl:#{build_task} build on jenkins builder"
      task build_task => [ "pl:fetch", "pl:load_extras" ] do
        invoke_task("pl:jenkins:post", "pl:#{build_task}")
      end
    end

    desc "Jenkins UBER build: build all the things with jenkins"
    task :uber_build do
      uber_tasks = ["jenkins:deb_all", "jenkins:mock_all", "jenkins:tar"]
      uber_tasks << "jenkins:dmg" if @build.build_dmg
      uber_tasks << "jenkins:gem" if @build.build_gem
      uber_tasks.map { |t| "pl:#{t}" }.each { |t| invoke_task(t) }
    end

    desc "Retrieve packages built by jenkins, sign, and ship all!"
    task :uber_ship => ["pl:fetch", "pl:load_extras"] do
      uber_tasks = ["jenkins:retrieve", "jenkins:sign_all", "uber_ship", "remote:freight", "remote:update_yum_repo" ]
      uber_tasks.map { |t| "pl:#{t}" }.each { |t| Rake::Task[t].invoke }
      Rake::Task["pl:jenkins:ship"].invoke("shipped")
    end
  end
end

##
# If this is a PE project, we want PE tasks as well. However, because the
# PE tasks use :remote as their default (e.g., not namespaced under remote)
# we have to explicily use the "local" tasks, since these will be local
# builds on jenkins agents. Also, we support building on SLES for PE, so we
# add a sles task.
#
if @build.build_pe
  namespace :pe do
    namespace :jenkins do
      tasks << "sles"
      tasks.each do |build_task|
        desc "Queue pe:#{build_task} build on jenkins builder"
        task build_task => ["pl:fetch", "pl:load_extras"] do
          check_var("PE_VER", @build.pe_version)
          invoke_task("pl:jenkins:post", "pe:local_#{build_task}")
        end
      end

      desc "Queue builds of all PE packages for this project in Jenkins"
      task :uber_build do
        check_var("PE_VER", @build.pe_version)
        ["deb_all", "mock_all", "sles"].each do |task|
          invoke_task("pe:jenkins:#{task}")
        end
      end

      desc "Retrieve PE packages built by jenkins, sign, and ship all!"
      task :uber_ship => ["pl:fetch", "pl:load_extras"] do
        check_var("PE_VER", @build.pe_version)
        ["pl:jenkins:retrieve", "pe:ship_rpms", "pe:ship_debs"].each do |task|
          Rake::Task[task].invoke
        end
        Rake::Task["pl:jenkins:ship"].invoke("shipped")
      end
    end
  end
end
