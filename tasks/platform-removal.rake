# This rake task creates tickets in jira for removing a platform.
#
def get_platform_ticket_vars
  vars = {}

  # configuration
  # Which tickets are we going to need for this platform?
  vars[:pe_only]      = Pkg::Util.boolean_value(Pkg::Util.get_var("PE_ONLY"))
  vars[:server]       = Pkg::Util.boolean_value(Pkg::Util.get_var("SERVER"))

  # What information do we need about this platform?
  vars[:platform_tag] = Pkg::Util.get_var("PLATFORM_TAG")
  vars[:eol_date] = Pkg::Util.get_var("EOL_DATE")
  vars[:eol_link] = Pkg::Util.get_var("EOL_LINK")

  # Jira authentication - do this after validating other params, so user doesn't need to
  # enter password only to find out they typo'd one of the above
  vars.merge(Pkg::Util::Jira.get_auth_vars)
end

def create_platform_tickets(jira, vars)
  description = {}
  description[:initial_email] = <<-DOC
Email should be sent out to puppet-users, puppet-dev, and puppet-announce notifying users the platform will no longer be supported.
DOC

  description[:pe_pipeline] = <<-DOC
Platform needs to be removed from PE pipelines.
DOC

  description[:pa_pipeline] = <<-DOC
Platform needs to be removed from puppet-agent pipelines.
DOC

  description[:beaker_hostgenerator] = <<-DOC
The platform definition and any special tweaks need to be removed from https://github.com/puppetlabs/beaker-hostgenerator
DOC

  description[:puppetlabs_release] = <<-DOC
Remove the platform from both PC* and pl-build-tools branch in puppetlabs-release
https://github.com/puppetlabs/puppetlabs-release/tree/PC1/configs/platforms
https://github.com/puppetlabs/puppetlabs-release/tree/pl-build-tools/configs/platforms
DOC

  description[:puppet_agent] = <<-DOC
Remove platform definition and any special tweaks from puppet-agent https://github.com/puppetlabs/puppet-agent/tree/master/configs/platforms
DOC

  description[:pl_build_tools_vanagon] = <<-DOC
Remove platform definition and any special tweaks from pl-build-tools-vanagon https://github.com/puppetlabs/pl-build-tools-vanagon/tree/master/configs/platforms
DOC

  description[:packaging] = <<-DOC
Remove platform definition packaging hash https://github.com/puppetlabs/packaging/blob/master/lib/packaging/platforms.rb
DOC

  description[:os_mirror] = <<-DOC
Remove platform from applicable os-mirror manifest in puppetlabs-modules
https://github.com/puppetlabs/puppetlabs-modules/tree/production/site/service/manifests/mrepo
https://github.com/puppetlabs/puppetlabs-modules/tree/production/site/service/files/mrepo
DOC

  description[:vmpooler] = <<-DOC
Remove platform from vmpooler
DOC

  description[:graphite_vmpooler] = <<-DOC
Remove platform from graphite
DOC

  description[:repositories] = <<-DOC
Remove platform from public facing repositories.  At current there may not be a an archive location to store them.  Confirm within RE prior to action.
DOC

  description[:final_email] = <<-DOC
Email should be sent out to puppet-users, puppet-dev, and puppet-announce confirming platform has been removed.
DOC

  description[:server_pipeline] = <<-DOC
Platform needs to be removed from puppetserver pipelines.
DOC

  description[:pdb_pipeline] = <<-DOC
Platform needs to be removed from puppetdb pipelines.
DOC

  description[:ez] = <<-DOC
Platform needs to be removed from ezbake build targets.
DOC

  # The subtickets to create for the individual tasks
  subtickets =
  [
    {
      :short_name   => 'initial_email',
      :project      => 'CPR',
      :summary      => "Send email to community notifying of #{vars[:platform_tag]} removal",
      :description  => description[:initial_email],
      :story_points => '1',
    },
    {
      :short_name   => 'pe_pipeline',
      :project      => 'PE',
      :summary      => "Remove #{vars[:platform_tag]} from PE integration pipelines",
      :description  => description[:pe_pipeline],
      :story_points => '3',
      :blocked_by   => ['initial_email'],
    },
    {
      :short_name   => 'pa_pipeline',
      :project      => 'PA',
      :summary      => "Remove #{vars[:platform_tag]} from puppet-agent pipelines",
      :description  => description[:pa_pipeline],
      :story_points => '3',
      :blocked_by   => ['pe_pipeline'],
    },
    {
      :short_name   => 'beaker_hostgenerator',
      :project      => 'QENG',
      :summary      => "Remove #{vars[:platform_tag]} from beaker-hostgenerator",
      :description  => description[:beaker_hostgenerator],
      :story_points => '1',
      :blocked_by   => ['pe_pipeline', 'pa_pipeline'],
    },
    {
      :short_name   => 'puppetlabs_release',
      :project      => 'RE',
      :summary      => "Remove #{vars[:platform_tag]} from puppetlabs-release",
      :description  => description[:puppetlabs_release],
      :story_points => '1',
      :blocked_by   => ['pa_pipeline'],
    },
    {
      :short_name   => 'puppet_agent',
      :project      => 'RE',
      :summary      => "Remove #{vars[:platform_tag]} platform definition from puppet-agent",
      :description  => description[:puppet_agent],
      :story_points => '1',
      :blocked_by   => ['pa_pipeline'],
    },
    {
      :short_name   => 'pl_build_tools_vanagon',
      :project      => 'RE',
      :summary      => "Remove #{vars[:platform_tag]} platform definition from pl-build-tools-vanagon",
      :description  => description[:pl_build_tools_vanagon],
      :story_points => '1',
      :blocked_by   => ['puppet_agent'],
    },
    {
      :short_name   => 'packaging',
      :project      => 'RE',
      :summary      => "Remove #{vars[:platform_tag]} platform definition from packaging",
      :description  => description[:packaging],
      :story_points => '1',
      :blocked_by   => ['puppet_agent'],
    },
    {
      :short_name   => 'os_mirror',
      :project      => 'RE',
      :summary      => "Remove #{vars[:platform_tag]} from osmirror in puppetlabs-modules",
      :description  => description[:os_mirror],
      :story_points => '1',
      :blocked_by   => ['puppet_agent'],
    },
    {
      :short_name   => 'vmpooler',
      :project      => 'RE',
      :summary      => "Remove #{vars[:platform_tag]} from vmpooler",
      :description  => description[:vmpooler],
      :story_points => '2',
      :blocked_by   => ['os_mirror'],
    },
    {
      :short_name   => 'graphite_vmpooler',
      :project      => 'OPS',
      :summary      => "Remove #{vars[:platform_tag]} from graphite (vmpooler)",
      :description  => description[:graphite_vmpooler],
      :story_points => '1',
      :blocked_by   => ['vmpooler'],
    },
    {
      :short_name   => 'repositories',
      :project      => 'CPR',
      :summary      => "Remove #{vars[:platform_tag]} from repositories",
      :description  => description[:repositories],
      :story_points => '1',
      :blocked_by   => ['packaging'],
    },
    {
      :short_name   => 'final_email',
      :project      => 'CPR',
      :summary      => "Send email to community confirming #{vars[:platform_tag]} removal",
      :description  => description[:final_email],
      :blocked_by   => ['repositories'],
    },
  ]

  # The subtickets for additonal server tasks
  if vars[:server]
    subtickets.push(
      {
        :short_name   => 'server_pipeline',
        :project      => 'SERVER',
        :summary      => "Remove #{vars[:platform_tag]} from puppetserver pipelines",
        :description  => description[:server_pipeline],
        :blocked_by   => ['initial_email'],
        :blocks   => ['pa_pipeline'],
      },
      {
        :short_name   => 'pdb_pipeline',
        :project      => 'PDB',
        :summary      => "Remove #{vars[:platform_tag]} from puppetdb pipelines",
        :description  => description[:pdb_pipeline],
        :blocked_by   => ['initial_email'],
        :blocks   => ['pa_pipeline'],
      },
      {
        :short_name   => 'ez',
        :project      => 'EZ',
        :summary      => "Remove #{vars[:platform_tag]} from ezbake build targets",
        :description  => description[:ez],
        :blocked_by   => ['initial_email', 'server_pipeline', 'pdb_pipeline'],
      },
    )
  end
  ## MAIN EPIC

  summary = "Remove #{vars[:platform_tag]}"
  description[:top_level_ticket] = <<-DOC
#{vars[:platform_tag]} will reach EOL on #{vars[:eol_date]}[1]. This epic is meant to track the effort to
remove the platform from applicable pipelines and support infrastructure.
[1] - #{vars[:eol_link]}
DOC

  # Values for the main ticket
  parent_project  = vars[:pe_only] ? 'RE' : 'CPR'
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

    # Set the ticket Scrum Team based on ticket type
    subticket[:scrum_team] = 'Release Engineering' if !subticket[:scrum_team] && (['CPR', 'EZ', 'PA', 'PDB', 'PE', 'RE', 'SERVER'].include? subticket[:project])

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
      if (['RE', 'CPR'].include? subticket[:project]) && (!subticket[:type] || subticket[:type] != 'Epic')
        # Add any RE tickets to this epic
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
Create tickets to remove supported platform
EOS

  task :platform_removal do
    vars = get_platform_ticket_vars
    jira = Pkg::Util::Jira.new(vars[:username], vars[:site])

    vars[:base64_encoding] = Pkg::Util.base64_encode("#{vars[:username]}:#{jira.client.options[:password]}")

    puts "Creating new platform tickets based on:"
    require 'pp'
    pp vars.select { |k, v| k != :password }

    create_platform_tickets(jira, vars)
  end
end
