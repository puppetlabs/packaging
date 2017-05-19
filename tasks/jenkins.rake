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
#################
#
# #!/bin/bash
#
# SHA=$(echo $BUILD_PROPERTIES | cut -d '.' -f1)
#
# echo "Build type: $BUILD_TYPE"
#
# ### Create a local clone of the git-bundle that was passed
# # The bundle is a tarball, and since this is a project-agnostic
# # job, we don't actually know what's in it, just that it's a
# # git bundle.
# #
#
# [ -f "PROJECT_BUNDLE" ] || exit 1
# mkdir project && tar -xzf PROJECT_BUNDLE -C project/
#
# pushd project
#   git clone --recursive $(ls) git_repo
#
#     pushd git_repo
#
#     ### Clone the packaging repo
#     rake package:bootstrap
#
#     ### Perform the build
#     rake pl:build_from_params PARAMS_FILE=$WORKSPACE/BUILD_PROPERTIES
#
#     ### Send the results
#     rake pl:jenkins:ship["artifacts"] PARAMS_FILE=$WORKSPACE/BUILD_PROPERTIES
#
#   popd
# popd
#
# ### Create the repositories from our project by trigger a downstream job
# ### Because we can't trigger downstream with a File Parameter, we use curl
# if [ "$BUILD_TYPE" = "rpm" ] || [ "$BUILD_TYPE" = "deb" ] ; then
#   curl -i -Fname=PROJECT_BUNDLE -Ffile0=@PROJECT_BUNDLE -FSubmit=Build -Fjson="{\"parameter\":[{\"name\":\"PROJECT_BUNDLE\",\"file\":\"file0\"}]}" \
#   http://jenkins-release.delivery.puppetlabs.net/job/puppetlabs-packaging-repo-creation/build
# fi
#
# ### If a downstream job was passed, trigger it now
# if [ -n "$DOWNSTREAM_JOB" ] ; then
#   pushd project
#     pushd git_repo
#       rake pl:jenkins:post["$DOWNSTREAM_JOB"] PARAMS_FILE=$WORKSPACE/BUILD_PROPERTIES
#     popd
#   popd
# fi
#
#################

namespace :pl do
  namespace :jenkins do
    ##
    # Do the heavy lifting. This task generates the URL for the jenkins job and posts it.
    # It expects a the following arguments
    # 1. :build_task => The lower-level pl: or pe: task we're executing, e.g. pl:deb_all
    #
    task :post_build, :build_task do |t, args|
      # Check for a dirty tree before allowing a remote build that is doomed to unexpected results
      Pkg::Util::Git.fail_on_dirty_source

      # We use JSON for parsing the json part of the submission to JSON
      Pkg::Util.require_library_or_fail 'json'

      build_task = args.build_task
      ##
      # We set @:task of Pkg::Config manually with our task data so the remote
      # build knows what to do. Puppetdb needs early knowledge of if this is
      # a PE build, so we always this along as an environment variable task
      # argument if its the case.
      #
      Pkg::Config.task = { :task => "#{build_task}", :args => nil }
      Pkg::Config.task[:args] = ["PE_BUILD=true"] if @build_pe
      #
      # Determine the type of build we're doing to inform jenkins
      build_type = case build_task
        when /deb/
          if Pkg::Config.default_cow.split('-')[1] =~ /cumulus/
            "cumulus"
          else
            "deb"
          end
        when /mock/ then "rpm"
        when /dmg|apple/ then "dmg"
        when /gem/ then "gem"
        when /tar/ then "tar"
        else raise "Could not determine build type for #{build_task}"
      end

      # Create a string of metrics to send to Jenkins for data analysis
      dist = case build_type
        when /deb/ then Pkg::Config.default_cow.split('-')[1]
        when /rpm/
          if Pkg::Config.pe_version
            Pkg::Config.final_mocks.split(' ')[0].split('-')[2]
          else
            Pkg::Config.final_mocks.split(' ')[0].split('-')[1..2].join("")
          end
        when /dmg/ then "apple"
        when /gem/ then "gem"
        when /sles/ then "sles"
        when /tar/ then "tar"
        else raise "Could not determine build type for #{build_task}"
      end

      if Pkg::Config.pe_version
        metrics = "#{ENV['USER']}~#{Pkg::Config.version}~#{Pkg::Config.pe_version}~#{dist}~#{Pkg::Config.team}"
      else
        metrics = "#{ENV['USER']}~#{Pkg::Config.version}~N/A~#{dist}~#{Pkg::Config.team}"
      end
      #
      # Create the data files to send to jenkins
      properties = Pkg::Config.config_to_yaml
      bundle = Pkg::Util::Git.bundle('HEAD')

      # Construct the parameters, which is an array of hashes we turn into JSON
      parameters = [{ "name" => "BUILD_PROPERTIES", "file"  => "file0" },
                    { "name" => "PROJECT_BUNDLE",   "file"  => "file1" },
                    { "name" => "PROJECT",          "value" => "#{Pkg::Config.project}" },
                    { "name" => "BUILD_TYPE",       "label" => "#{build_type}" },
                    { "name" => "METRICS",          "value" => "#{metrics}" }]

      # Initialize the args array that will hold all of the arguments we pass
      # to the curl utility method.
      args = []

      # If the environment variable "DOWNSTREAM_JOB" was passed, we want to
      # send this value to the build job as well, so it knows to trigger a
      # downstream job, and with what URI.
      if ENV['DOWNSTREAM_JOB']
        parameters << { "name" => "DOWNSTREAM_JOB", "value" => ENV['DOWNSTREAM_JOB'] }
        args << ["-Fname=DOWNSTREAM_JOB", "-Fvalue=#{ENV['DOWNSTREAM_JOB']}"]
      end

      # Contruct the json string
      json = JSON.generate("parameter" => parameters)

      # Construct the remaining form arguments. For visual clarity, params that are tied
      # together are on the same line.
      #
      args <<  [
      "-Fname=BUILD_PROPERTIES", "-Ffile0=@#{properties}",
      "-Fname=PROJECT_BUNDLE",   "-Ffile1=@#{bundle}",
      "-Fname=PROJECT",          "-Fvalue=#{Pkg::Config.project}",
      "-Fname=BUILD_TYPE",       "-Fvalue=#{build_type}",
      "-Fname=METRICS",          "-Fvalue=#{metrics}",
      "-FSubmit=Build",
      "-Fjson=#{json.to_json}",
      ]

      # We have several arrays inside args by now, flatten it up.
      args.flatten!

      # Construct the job url
      #
      job_url = "#{Pkg::Config.jenkins_build_host}/job/#{Pkg::Config.jenkins_packaging_job}"
      trigger_url = "#{job_url}/build"

      # Call out to the curl_form_data utility method in 00_utils.rake
      #
      begin
        _, retval = Pkg::Util::Net.curl_form_data(trigger_url, args)
        if Pkg::Util::Execution.success?(retval)
          puts "Build submitted. To view your build results, go to #{job_url}"
          puts "Your packages will be available at http://#{Pkg::Config.builds_server}/#{Pkg::Config.project}/#{Pkg::Config.ref}"
        else
          fail "An error occurred submitting the job to jenkins. Take a look at the preceding http response for more info."
        end
      ensure
        # Clean up after ourselves
        rm bundle
        rm properties
      end
    end
  end
end

##
# A task listing for creating jenkins tasks for our various pl: and pe: build
# tasks. We can assume deb, mock, but not gem/dmg.
#
tasks = ["deb", "mock", "tar"]
tasks << "gem" if Pkg::Config.build_gem and !Pkg::Config.build_pe
tasks << "dmg" if Pkg::Config.build_dmg and !Pkg::Config.build_pe

namespace :pl do
  namespace :jenkins do
    tasks.each do |build_task|
      desc "Queue pl:#{build_task} build on jenkins builder"
      task build_task => "pl:fetch" do
        Pkg::Util::RakeUtils.invoke_task("pl:jenkins:post_build", "pl:#{build_task}")
      end
    end

    # While pl:remote:deb_all does all cows in serially, with jenkins we
    # parallelize them. This breaks the cows up and posts a build for all of
    # them. We have to sleep 5 because jenkins drops the builds when we're
    # DOSing it with our packaging.
    desc "Queue pl:deb_all on jenkins builder"
    task :deb_all => "pl:fetch" do
      Pkg::Config.cows.split(' ').each do |cow|
        Pkg::Config.default_cow = cow
        Pkg::Util::RakeUtils.invoke_task("pl:jenkins:post_build", "pl:deb")
        sleep 5
      end
    end

    # This does the mocks in parallel
    desc "Queue pl:mock_all on jenkins builder"
    task :mock_all => "pl:fetch" do
      Pkg::Config.final_mocks.split(' ').each do |mock|
        Pkg::Config.default_mock = mock
        Pkg::Util::RakeUtils.invoke_task("pl:jenkins:post_build", "pl:mock")
        sleep 5
      end
    end

    desc "Retrieve packages built by jenkins, sign, and ship all!"
    task :uber_ship => "pl:fetch" do
      uber_tasks = %w(
        jenkins:retrieve
        jenkins:sign_all
        uber_ship
        ship_gem
        remote:update_apt_repo
        remote:deploy_apt_repo
        remote:update_yum_repo
        remote:deploy_yum_repo
        remote:update_ips_repo
        remote:deploy_dmg_repo
        remote:deploy_swix_repo
        remote:deploy_msi_repo
        remote:deploy_tar_repo
      )

      if Pkg::Util.boolean_value(Pkg::Config.answer_override) && !Pkg::Config.foss_only
        fail "Using ANSWER_OVERRIDE without FOSS_ONLY=true is dangerous!"
      end

      puts '**************'
      puts 'WARNING: Shipping software currently requires manual CDN Updates'
      puts 'Don\'t continue unless you or someone else around knows how to do this'
      puts '**************'
      puts 'Continue?'
      exit unless Pkg::Util.ask_yes_or_no

      # Some projects such as pl-build-tools do not stage to a separate server - so we do to deploy
      uber_tasks.delete("remote:deploy_apt_repo") if Pkg::Config.apt_host == Pkg::Config.apt_signing_server
      uber_tasks.delete("remote:deploy_yum_repo") if Pkg::Config.yum_host == Pkg::Config.yum_staging_server
      uber_tasks.delete("remote:deploy_dmg_repo") if Pkg::Config.dmg_host == Pkg::Config.dmg_staging_server
      uber_tasks.delete("remote:deploy_swix_rep") if Pkg::Config.swix_host == Pkg::Config.swix_staging_server
      uber_tasks.delete("remote:deploy_tar_repo") if Pkg::Config.tar_host == Pkg::Config.tar_staging_server

      # Delete the ship_gem task if we aren't building gems
      uber_tasks.delete("ship_gem") unless Pkg::Config.build_gem

      # I'm adding this check here because if we rework the task ordering we're
      # probably going to need to muck about in here. -morgan
      if uber_tasks.first == 'jenkins:retrieve'
        # We need to run retrieve before we can delete tasks based on what
        # packages were built. Before this we were deleting tasks based on files
        # in a directory that hadn't been populated yet, so this would either
        # fail since all tasks would be removed, or would be running based on
        # files left over in packaging from the last ship.
        puts 'Do you want to run pl:jenkins:retrieve?'
        Rake::Task['pl:jenkins:retrieve'].invoke if Pkg::Util.ask_yes_or_no
        uber_tasks.delete('jenkins:retrieve')
      end

      # Don't update and deploy repos if packages don't exist
      # If we can't find a certain file type, delete the task
      if Dir.glob("pkg/**/*.deb").empty?
        uber_tasks.delete("remote:update_apt_repo")
        uber_tasks.delete("remote:deploy_apt_repo")
      end

      if Dir.glob("pkg/**/*.rpm").empty?
        uber_tasks.delete("remote:update_yum_repo")
        uber_tasks.delete("remote:deploy_yum_repo")
      end

      if Dir.glob("pkg/**/*.p5p").empty?
        uber_tasks.delete("remote:update_ips_repo")
      end

      if Dir.glob("pkg/**/*.dmg").empty?
        uber_tasks.delete("remote:deploy_dmg_repo")
      end

      if Dir.glob("pkg/**/*.swix").empty?
        uber_tasks.delete("remote:deploy_swix_repo")
      end

      if Dir.glob("pkg/**/*.msi").empty?
        uber_tasks.delete("remote:deploy_msi_repo")
      end

      if Dir.glob("pkg/*.tar.gz").empty?
        uber_tasks.delete("remote:deploy_tar_repo")
      end

      uber_tasks.map { |t| "pl:#{t}" }.each do |t|
        puts "Do you want to run #{t}?"
        Rake::Task[t].invoke if Pkg::Util.ask_yes_or_no
      end

      puts "Do you want to mark this release as successfully shipped?"
      Rake::Task["pl:jenkins:ship"].invoke("shipped") if Pkg::Util.ask_yes_or_no
    end
  end
end

##
# If this is a PE project, we want PE tasks as well.
#
if Pkg::Config.build_pe
  namespace :pe do
    namespace :jenkins do
      tasks.each do |build_task|
        desc "Queue pe:#{build_task} build on jenkins builder"
        task build_task => "pl:fetch" do
          Pkg::Util.check_var("PE_VER", Pkg::Config.pe_version)
          Pkg::Util::RakeUtils.invoke_task("pl:jenkins:post_build", "pe:#{build_task}")
        end
      end

      # While pl:remote:deb_all does all cows in serially, with jenkins we
      # parallelize them. This breaks the cows up and posts a build for all of
      # them. We have to sleep 5 because jenkins drops the builds when we're
      # DOSing it with our packaging.
      desc "Queue pe:deb_all on jenkins builder"
      task :deb_all => "pl:fetch" do
        Pkg::Util.check_var("PE_VER", Pkg::Config.pe_version)
        Pkg::Config.cows.split(' ').each do |cow|
          Pkg::Config.default_cow = cow
          Pkg::Util::RakeUtils.invoke_task("pl:jenkins:post_build", "pe:deb")
          sleep 5
        end
      end

      # This does the mocks in parallel
      desc "Queue pe:mock_all on jenkins builder"
      task :mock_all => "pl:fetch" do
        Pkg::Config.final_mocks.split(' ').each do |mock|
          Pkg::Config.default_mock = mock
          Pkg::Util::RakeUtils.invoke_task("pl:jenkins:post_build", "pe:mock")
          sleep 5
        end
      end

      desc "Retrieve PE packages built by jenkins, sign, and ship all!"
      task :uber_ship => "pl:fetch" do
        Pkg::Util.check_var("PE_VER", Pkg::Config.pe_version)
        ["pl:jenkins:retrieve", "pl:jenkins:sign_all", "pe:ship_rpms", "pe:ship_debs"].each do |task|
          Rake::Task[task].invoke
        end
        Rake::Task["pl:jenkins:ship"].invoke("shipped")
      end
    end
  end
end

##
# This task allows the packaging repo to post to an arbitrary jenkins job but
# it is very limited in that it does not model well the key => value format
# used when submitting form data on websites. This is primarily because rake
# does not allow us to elegantly pass arbitrary key => value pairs on the
# command line and have any idea how to reference them inside rake. We can pass
# KEY=VALUE along with our invokation, but unless KEY is statically coded into
# our task, we won't know how to reference it. Thus, this task will only take
# one argument, the uri of the jenkins job to post to. This can be passed
# either as an argument directly or as an environment variable "JOB" with the
# uri as the value. The argument is required. The second requirement is that
# the job to be called accept a string parameter with the name SHA. This will
# be the SHA of the commit of the project source code HEAD, and should be used
# by the job to check out this specific ref. To maintain the abstraction of the
# jenkins jobs, this specific task passes on no information about the build
# itself. The assumption is that the upstream jobs know about their project,
# and so do the downstream jobs, but packaging itself has no business knowing
# about it.
#
namespace :pl do
  namespace :jenkins do
    desc "Trigger a jenkins uri with SHA of HEAD as a string param, requires \"URI\""
    task :post, :uri do |t, args|
      uri = (args.uri or ENV['URI']) or fail "pl:jenkins:post requires a URI, either via URI= or pl:jenkin:post[URI]"

      # We use JSON for parsing the json part of the submission.
      begin
        require 'json'
      rescue LoadError
        fail "Couldn't require 'json'. JSON is required for sanely generating the string we curl to Jenkins."
      end

      # Assemble the JSON string for the JSON parameter
      json = JSON.generate("parameter" => [{ "name" => "SHA", "value"  => "#{Pkg::Config.ref}" }])

      # Assemble our arguments to the post
      args = [
      "-Fname=SHA", "-Fvalue=#{Pkg::Config.ref}",
      "-Fjson=#{json.to_json}",
      "-FSubmit=Build"
      ]

      _, retval = Pkg::Util::Net.curl_form_data(uri, args)
      if Pkg::Util::Execution.success?(retval)
        puts "Job triggered at #{uri}."
      else
        fail "An error occurred attempting to trigger the job at #{uri}. Please see the preceding http response for more info."
      end
    end
  end
end

