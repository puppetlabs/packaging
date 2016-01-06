# This rake task creates tickets in jira for a release.
#
def get_platform_ticket_vars
  vars = {}

  # configuration
  # Which tickets are we going to need for this platform?
  vars[:pe_only]      = Pkg::Util.get_var("PE_ONLY")

  # What information do we need about this platform?
  vars[:platform_tag] = Pkg::Util.get_var("PLATFORM_TAG")

  # Jira authentication - do this after validating other params, so user doesn't need to
  # enter password only to find out they typo'd one of the above
  vars.merge(Pkg::Util::Jira.get_auth_vars)
end

def create_platform_tickets(jira, vars)
  description = {}
  description[:update_confluence] = <<-DOC
The following confluence pages must be updated:
https://confluence.puppetlabs.com/display/PROD/FOSS+Supported+Platforms+for+PC1
https://confluence.puppetlabs.com/display/PROD/Supported+Platforms+for+Shallow+Gravy
https://confluence.puppetlabs.com/display/PROD/Supported+Platforms+for+Ankeny

This includes any FOSS PC repo or PE release pages that have been created since this (i.e., PC2, Burnside, 2016.2.0, etc.)
DOC

  description[:decide_tier] = <<-DOC
This decision should be made with all interested parties, including RE, QA, QE, PO, etc.

https://confluence.puppetlabs.com/pages/viewpage.action?pageId=31162677
https://confluence.puppetlabs.com/display/QA/Tiers+of+Supported+OS+Platforms

This decision is essential to help QA/QE decide how often tests are run aginst the new platform.
DOC

  description[:mirror_os] = <<-DOC
We need to mirror the repos for this platform, if this platform has a managable package management system.
DOC

  description[:pooler_image] = <<-DOC
A pooler image on http://vmpooler.delivery.puppetlabs.net/dashboard/ must be available
for building and testing against
DOC

  description[:pl_build_tools_configuration] = <<-DOC
https://github.com/puppetlabs/pl-build-tools-vanagon/tree/master/configs/platforms must
have a file associated with this new platform in order to build packages for this project.
There is a possibility that this ticket may also require vanagon work to add support to
vanagon to this new platform.
DOC

  description[:c_toolchain] = <<-DOC
Once vanagon and pl-build-tools-vanagon have support for the new platform, we need to build
and ship all the C++ toolchain packages. This includes GCC, CMake, Boost, etc. This will allow
us to build Facter and other native projects for this platform.
DOC

  description[:puppet_agent_configuration] = <<-DOC
Now that we have the buildtime dependencies satisfied, and we know vanagon support for this platform,
we can start building out the agent packages for it. We first need a platform definition at
https://github.com/puppetlabs/puppet-agent/tree/master/configs/platforms

This addition implies that we have everything in place to begin building puppet-agent platforms on #{vars[:platform_tag]}.
This means you'll have to verify the build to resolve this ticket. If vanagon doesn't yet have support for this platform,
you need to create a new ticket, block this ticket against that one, and add in vanagon support!
DOC

  description[:hostgenerator] = <<-DOC
Update beaker-hostgenerator (https://github.com/puppetlabs/beaker-hostgenerator) for #{vars[:platform_tag]}.
DOC

  description[:beaker] = <<-DOC
Make sure beaker can support running tests on #{vars[:platform_tag]}
DOC

  description[:platform_jenkins] = <<-DOC
Jenkins jobs should be updated to include the new target depending on which tier the target falls into (nightly, per commit, etc.).

This is for all puppet-agent jenkins pipelines.
DOC

  description[:internal_agent_ship] = <<-DOC
Edit the job configuration at http://jenkins-compose.delivery.puppetlabs.net/job/internal_puppet-agent_ship/configure to include #{vars[:platform_tag]}.

This will enable shipping agent builds for #{vars[:platform_tag]} to http://agent-downloads.delivery.puppetlabs.net.
DOC

  description[:s3_agent_ship] = <<-DOC
Edit the job configuration at http://jenkins-compose.delivery.puppetlabs.net/job/puppet-agent_s3-ship/configure to include #{vars[:platform_tag]}.

This will enable shipping agent builds for #{vars[:platform_tag]} to S3.
DOC

  description[:platform_hash] = <<-DOC
Update the hash at https://github.com/puppetlabs/packaging/blob/master/lib/packaging/config/platforms.rb to include the #{vars[:platform_tag]}.
DOC

  description[:build_data] = <<-DOC
Update either the foss_platforms or pe_platforms list in puppet-agent ext/build_defaults.yaml so it can be properly whitelisted for nightly builds.
DOC

  description[:pe_jenkins] = <<-DOC
Jenkins jobs should be updated to include the new target depending on which tier the target falls into (nightly, per commit, etc.).

This is for all PE Integration jenkins pipelines.
DOC


  description[:pe_integration] = <<-DOC
If #{vars[:platform_tag]} is also getting into PE, which it for sure should if it's an agent platform, we need to add it to the pe integration tests
DOC

  description[:pe_repo] = <<-DOC
pe_repo needs to be udpated to support installing the agent package on #{vars[:platform_tag]}
DOC

  description[:pre_suites] = <<-DOC
Get git tests working. AIO test failures can be found in the pipeline, and ticketed from there.
DOC

  description[:module_support] = <<-DOC
Notification of support for #{vars[:platform_tag]}. This likely means that common supported modules will have to be tested on #{vars[:platform_tag]}.
DOC

  description[:docs_support] = <<-DOC
Notification of support for #{vars[:platform_tag]}. Documentation should be updated to indicate that we now support #{vars[:platform_tag]} as an agent platform.
DOC

  # The subtickets to create for the individual tasks
  subtickets =
  [
    {
      :short_name   => 'update_confluence',
      :project      => 'RE',
      :summary      => "Update platform support confluence docs to include #{vars[:platform_tag]}",
      :description  => description[:update_confluence],
      :story_points => '2',
    },
    {
      :short_name   => 'decide_tier',
      :project      => 'QA',
      :summary      => "Decide which tier #{vars[:platform_tag]} belongs to",
      :description  => description[:decide_tier],
      :story_points => '2',
    },
    {
      :short_name   => 'mirror_os',
      :project      => 'RE',
      :summary      => "Create a mirror of #{vars[:platform_tag]}",
      :description  => description[:mirror_os],
      :story_points => '2',
    },
    {
      :short_name   => 'pooler_image',
      :project      => 'RE',
      :summary      => "Create a pooler image for #{vars[:platform_tag]}",
      :description  => description[:pooler_image],
      :story_points => '5',
    },
    {
      :short_name   => 'pl_build_tools_configuration',
      :project      => 'RE',
      :summary      => "Add #{vars[:platform_tag]} platform definition to pl-build-tools-vanagon",
      :description  => description[:pl_build_tools_configuration],
      :story_points => '2',
      :blocked_by   => ['pooler_image'],
    },
    {
      :short_name   => 'c_toolchain',
      :project      => 'RE',
      :summary      => "Build out C++ toolchain for #{vars[:platform_tag]}",
      :description  => description[:c_toolchain],
      :story_points => '5',
      :blocked_by   => ['pl_build_tools_configuration'],
    },
    {
      :short_name   => 'pl_gcc',
      :project      => 'RE',
      :summary      => "Build and ship pl-gcc for #{vars[:platform_tag]}",
      :parent       => 'c_toolchain',
    },
    {
      :short_name   => 'pl_cmake',
      :project      => 'RE',
      :summary      => "Build and ship pl-cmake for #{vars[:platform_tag]}",
      :parent       => 'c_toolchain',
    },
    {
      :short_name   => 'pl_boost',
      :project      => 'RE',
      :summary      => "Build and ship pl-boost for #{vars[:platform_tag]}",
      :parent       => 'c_toolchain',
    },
    {
      :short_name   => 'pl_yaml_cpp',
      :project      => 'RE',
      :summary      => "Build and ship pl-yaml-cpp for #{vars[:platform_tag]}",
      :parent       => 'c_toolchain',
    },
    {
      :short_name   => 'puppet_agent_configuration',
      :project      => 'PA',
      :summary      => "Add #{vars[:platform_tag]} platform definition to puppet-agent",
      :description  => description[:puppet_agent_configuration],
      :story_points => '2',
      :blocked_by   => ['c_toolchain'],
    },
    {
      :short_name   => 'hostgenerator',
      :project      => 'QENG',
      :summary      => "Add #{vars[:platform_tag]} to beaker-hostgenerator",
      :description  => description[:hostgenerator],
      :story_points => '1',
      :blocked_by   => ['pooler_image'],
    },
    {
      :short_name   => 'beaker',
      :project      => 'BKR',
      :summary      => "Add support for #{vars[:platform_tag]}",
      :description  => description[:beaker],
      :story_points => '2',
      :type         => 'New Feature',
      :blocked_by   => ['pooler_image'],
    },
    {
      :short_name   => 'platform_hash',
      :project      => 'RE',
      :summary      => "Update packaging platform hash to include #{vars[:platform_tag]}",
      :description  => description[:platform_hash],
      :story_points => '1',
      :blocked_by   => ['puppet_agent_configuration', 'pooler_image'],
    },
    {
      :short_name   => 'build_data',
      :project      => 'RE',
      :summary      => "Update build_data to whitelist #{vars[:platform_tag]} for nightlies",
      :description  => description[:build_data],
      :story_points => '1',
      :blocked_by   => ['puppet_agent_configuration', 'pooler_image', 'platform_hash'],
    },
    {
      :short_name   => 'platform_jenkins',
      :project      => 'QENG',
      :summary      => "Update platform puppet-agent jenkins pipelines to include #{vars[:platform_tag]}",
      :description  => description[:jenkins],
      :story_points => '1',
      :blocked_by   => ['build_data', 'puppet_agent_configuration', 'puppet_pre_suites', 'facter_pre_suites', 'hiera_pre_suites', 'pooler_image', 'decide_tier'],
      :components   => ['CI', 'Scrum Team - Client Platform'],
    },
    {
      :short_name   => 'internal_agent_ship',
      :project      => 'RE',
      :summary      => "Update internal puppet-agent ship job to include #{vars[:platform_tag]}",
      :description  => description[:internal_agent_ship],
      :story_points => '1',
      :blocked_by   => ['platform_jenkins'],
    },
    {
      :short_name   => 's3_agent_ship',
      :project      => 'RE',
      :summary      => "Update S3 puppet-agent ship job to include #{vars[:platform_tag]}",
      :description  => description[:s3_agent_ship],
      :story_points => '1',
      :blocked_by   => ['platform_jenkins'],
    },
    {
      :short_name   => 'pe_repo',
      :project      => 'PE',
      :summary      => "Add #{vars[:platform_tag]} to pe_repo module",
      :description  => description[:pe_repo],
      :blocked_by   => ['platform_jenkins', 'puppet_pre_suites', 'facter_pre_suites', 'hiera_pre_suites', 'internal_agent_ship', 's3_agent_ship'],
    },
    {
      :short_name   => 'pe_jenkins',
      :project      => 'QENG',
      :summary      => "Update PE Integration jenkins pipelines to include #{vars[:platform_tag]}",
      :description  => description[:pe_integration],
      :blocked_by   => ['pe_repo', 'platform_jenkins', 'internal_agent_ship', 's3_agent_ship'],
      :story_points => '1',
      :components   => ['CI', 'Scrum Team - Integration'],
    },
    {
      :short_name   => 'module_support',
      :project      => 'FM',
      :summary      => "Intention to support #{vars[:platform_tag]} as an agent platform",
      :description  => description[:module_support],
      :blocked_by   => ['beaker', 'pooler_image']
    },
    {
      :short_name   => 'docs_support',
      :project      => 'DOC',
      :summary      => "Intention to support #{vars[:platform_tag]} as an agent platform",
      :description  => description[:docs_support],
    },
  ]


  ## MAIN TICKET

  summary = "Add #{vars[:platform_tag]} as a supported agent platform"
  description[:top_level_ticket] = <<-DOC
It has come time to add in support for #{vars[:platform_tag]}. This epic is meant to track the effort to
stand up build and test infrastructure for the new platform. Once that work has been completed, users may
see the new platform available through nightly builds. Otherwise, it will become available whenever the
next release happens.

This epic is only to add support for this platform in the agent stack. The server stack work for this
platform will happen in a separate epic.
DOC

  # Values for the main ticket
  parent_project  = 'PA'
  parent_assignee = vars[:username]

  jira.user(parent_assignee)
  jira.project(parent_project)

  main_ticket = {
    :summary => summary,
    :description => description[:top_level_ticket],
    :project => parent_project,
    :assignee => parent_assignee,
    :type => 'Epic',
  }

  parent_key, _ = jira.create_issue(main_ticket)

  puts "Main epic: #{parent_key} (#{parent_assignee}) - #{summary}"


  ## SUPPORTING TICKETS

  # We want to keep track of the tickets we've already created so that we can define
  # relationships between them in a human-readable way.
  subticket_hash = {}

  # Create subtasks for each step of the release process
  subtickets.each do |subticket|

    jira.user(subticket[:assignee]) if subticket[:assignee]
    jira.project(subticket[:project])

    # Is this ticket a subtask with a parent ticket? If so, we need to figure out the parent key
    # and pass that information in during the ticket creation process
    if subticket[:parent]
      subticket[:parent] = subticket_hash[subticket[:parent]]['key']
      subticket[:type] = 'Sub-task'
      unless subticket[:parent].match(subticket[:project])
        fail "Subtickets must be in the same project as their parent ticket. Did you mean to have ticket ##{subticket[:index]} block #{subticket[:parent]}?"
      end
    end

    # Define the relationship of all tickets that this ticket is blocked by
    # so we can pass in the key of the blocking ticket
    blocked_by = []
    if subticket[:blocked_by]
      subticket[:blocked_by].each do |linked_ticket|
        blocked_by << subticket_hash[linked_ticket]['key']
      end
    end

    # Define the relationship of all tickets this ticket blocks so we can
    # pass in the key of the blocked ticket
    blocks = []
    if subticket[:blocks]
      subticket[:blocks].each do |linked_ticket|
        blocks << subticket_hash[linked_ticket]['key']
      end
    end

    # If this ticket already has an epic parent, we don't want to link it against the main epic
    # since the epic parent *should* already be linked against the main ticket
    if subticket[:epic_parent]
      subticket[:epic_parent] = subticket_hash[subticket[:epic_parent]]['key']
    else # otherwise, we definitely need to link it to the main epic ticket somehow
      if subticket[:project] == 'PA' && (!subticket[:type] || subticket[:type] != 'Epic')
        # Add any PA tickets to this epic
        subticket[:epic_parent] = parent_key
      elsif !subticket[:parent]
        # If the ticket isn't a sub-task (meaning it doesn't have a parent, otherwise the parent ticket will be linked against
        # the main issue), then we have to block it against the main issue. Our policy is that only tickets in the same project
        # as the epic should be in that epic, which is why we have to block tickets that are not in the RE or CPR projects against
        # the main epic ticket.
        blocks << parent_key
      end
    end

    key, id = jira.create_issue(subticket)

    ## DEFINE RELATIONSHIPS FOR THIS SUBTICKET
    # we don't currently have the ability to define these relationships on ticket creation,
    # so we have to do it after the ticket has been created. We can only define these
    # relationships if we have the key for both tickets that we are linking.

    # Tickets that are blocking this ticket
    blocked_by.each do |link|
      Pkg::Util::Jira.link_issues(link, key, vars[:site], vars[:base64_encoding])
    end

    # Tickets that this ticket is blocking
    blocks.each do |link|
      Pkg::Util::Jira.link_issues(key, link, vars[:site], vars[:base64_encoding])
    end

    subticket_hash[subticket[:short_name]] = { 'key' => key, 'id' => id }

    puts "\t#{key} (#{subticket[:assignee]}) - #{subticket[:summary]}"
  end
end

namespace :pl do
  desc <<-EOS
Create tickets to provide the agent stack for a new platform
EOS

  task :agent_tickets do
    vars = get_platform_ticket_vars
    jira = Pkg::Util::Jira.new(vars[:username], vars[:site])

    vars[:base64_encoding] = Pkg::Util.base64_encode("#{vars[:username]}:#{jira.client.options[:password]}")

    puts "Creating new platform tickets based on:"
    require 'pp'
    pp vars.select { |k, v| k != :password }

    create_platform_tickets(jira, vars)
  end
end
