# This rake task creates tickets in jira for a release.
#
def get_server_platform_ticket_vars
  vars = {}

  # configuration
  # Which tickets are we going to need for this platform?
  vars[:foss_only] = Pkg::Util.get_var("FOSS_ONLY").downcase
  fail "FOSS_ONLY must be set to either true or false" unless ["true", "false"].include?(vars[:foss_only])

  vars[:pe_ver] = Pkg::Util.get_var("PE_VER") if vars[:foss_only] == "false"

  vars[:platform_tag] = Pkg::Util.get_var("PLATFORM_TAG")

  # Jira authentication - do this after validating other params, so user doesn't need to
  # enter password only to find out they typo'd one of the above
  vars.merge(Pkg::Util::Jira.get_auth_vars)
end

def create_server_platform_tickets(jira, vars)
  description = {}
  description[:update_confluence] = <<-DOC
The following confluence pages must be updated:
https://confluence.puppetlabs.com/display/PROD/FOSS+Supported+Platforms+for+PC1
https://confluence.puppetlabs.com/display/PROD/Supported+Platforms+for+Shallow+Gravy
https://confluence.puppetlabs.com/display/PROD/Supported+Platforms+for+Ankeny
etc

This includes any FOSS PC repo or PE release pages that have been created since this (i.e., PC2, Burnside, 2016.2.0, etc.)
DOC

  description[:create_cows] = <<-DOC
https://github.com/puppetlabs/puppetlabs-debbuilder or https://github.com/puppetlabs/puppetlabs-rpmbuilder need to be updated

You also likely need to update https://github.com/puppetlabs/puppetlabs-modules/blob/production/Puppetfile to pull in the new changes.

New MOCKs should be relatively straight forward. New COWs, however, require any referenced repos to be real. In our case, this means
the repo for the new platform at apt.puppetlabs.com and pl-build-tools.delivery.puppetlabs.net should already exist and contain packages.
Otherwise, the cows will not be created successfully. You will either have puppet failing to create the cows, or you will be stuck with
broken COWs on all the deb-builders which have to be manually removed.
DOC

  description[:puppetserver] = <<-DOC
Update https://github.com/puppetlabs/ci-job-configs/blob/master/jenkii/platform/projects/puppetserver.yaml to include the new platform.

Ensure the new platform is only being added to the appripriate branch pipelines. If this is in fact a new platform, we shouldn't be trying
to run upgrade tests on it.
DOC

  description[:ami] = <<-DOC
Update https://github.com/puppetlabs/puppetlabs-packer to ensure we are building the AMI from the correct source.
DOC

  description[:puppetdb] = <<-DOC
Update https://github.com/puppetlabs/ci-job-configs/blob/master/jenkii/enterprise/projects/puppetdb.yaml to include the new platform.
DOC

  description[:ezbake] = <<-DOC
Add the new platform to the default list of FOSS build targets for EZBake builds.
DOC

  description[:pe_ezbake] = <<-DOC
Add the new platform to the default list of PE build targets for EZBake builds.
DOC

  description[:puppet_agent] = <<-DOC
Ensure the puppet-agent package for this platform has been promoted into PE #{vars[:pe_ver]}.

This means there is a reference to it in packages.json on the appropriate branch in enterprise-dist and
the packages exist in a valid repo on enterprise.delivery.puppetlabs.net for the appriopriate version of PE.
DOC

  description[:pe_client_tools] = <<-DOC
Add a platform definition, add the new platform to ext/build_defaults.yaml, ensure the package builds,
and update the ci pipeline to build and test against the new platform.
DOC

  description[:pe_r10k] = <<-DOC
Add a platform definition, add the new platform to ext/build_defaults.yaml, ensure the package builds,
and update the ci pipeline to build and test against the new platform.
DOC

  description[:pe_puppetserver] = <<-DOC
Update the pe puppetserver pipelines to build and test the new platform.
DOC

  description[:pe_puppetdb] = <<-DOC
Update the pe puppetdb pipelines to build and test the new platform.
DOC

  description[:pe_razor_server] = <<-DOC
Update the pe puppetdb pipelines to build and test the new platform.
DOC

  description[:enterprise_dist] = <<-DOC
Build, ship and promote packages housed in enterprise-dist
DOC

  description[:console_services] = <<-DOC
https://github.com/puppetlabs/pe-console-services
DOC

  description[:pe_installer] = <<-DOC
https://github.com/puppetlabs/higgs
DOC

  description[:pe_orechestration_services] = <<-DOC
https://github.com/puppetlabs/pe-orchestration-services
DOC

  description[:pe_puppet_license_cli] = <<-DOC
https://github.com/puppetlabs/puppet-license-cli
DOC

  description[:pe_license] = <<-DOC
https://github.com/puppetlabs/pe-license
DOC

  description[:compose] = <<-DOC
Either release or integration will need to update the enterprise-dist/Rakefile @platform_info to include Ubuntu 16.04, and verify that promotions are composing 16.04 tarballs.
DOC

  description[:integration_pipelines] = <<-DOC
Update the pe_integration pipeline in ci-job-configs to test the new platform

Server packages will be coming after we have puppet-agent packages.
We will need to add Ubuntu 16.04 to the master platforms we test.
We will need to either filter upgrades or break out separate platform defaults for upgrades.
DOC

  description[:install_pe_meep] = <<-DOC
Hopefully this will be as easy as unpacking a PE 16.04 tarball on a 16.04 node and running
puppet-enterprise-installer -c pe-manager/conf.d/pe.conf
DOC

  description[:install_pe_legacy] = <<-DOC
Use legacy installer to install PE on the new platform
DOC

  description[:uninstall_pe] = <<-DOC
Ensure uninstall on the new platform executes successfully
DOC

  description[:support_script] = <<-DOC
The support script needs to handle the new platform.
DOC

  description[:module_support] = <<-DOC
Notification of support for #{vars[:platform_tag]}. This likely means that common supported modules will have to be tested on #{vars[:platform_tag]}.
DOC

  description[:docs_support] = <<-DOC
Notification of support for #{vars[:platform_tag]}. Documentation should be updated to indicate that we now support #{vars[:platform_tag]} as a master platform.
DOC

  # The subtickets to create for the individual tasks
  subtickets =
  [
    {
      :short_name   => 'update_confluence',
      :project      => 'RE',
      :summary      => "Update confluence pages to include #{vars[:platform_tag]}",
      :description  => description[:update_confluence],
      :story_points => '2',
    },
    {
      :short_name   => 'create_cows',
      :project      => 'RE',
      :summary      => "Create COWS/MOCKS for #{vars[:platform_tag]}",
      :description  => description[:create_cows],
      :story_points => '2',
    },
    {
      :short_name   => 'puppetserver',
      :project      => 'SERVER',
      :summary      => "Update ci-job-configs to build/test #{vars[:platform_tag]}",
      :description  => description[:puppetserver],
      :story_points => '2',
      :blocked_by   => ['create_cows'],
    },
    {
      :short_name   => 'ami',
      :project      => 'RE',
      :summary      => "Create AMI of #{vars[:platform_tag]} for PDB testing",
      :description  => description[:ami],
      :story_points => '2',
    },
    {
      :short_name   => 'puppetdb',
      :project      => 'PDB',
      :summary      => "Update ci-job-configs to build/test #{vars[:platform_tag]}",
      :description  => description[:puppetdb],
      :story_points => '2',
      :blocked_by   => ['create_cows', 'puppetserver', 'ami'],
    },
    {
      :short_name   => 'ezbake',
      :project      => 'EZ',
      :summary      => "Add #{vars[:platform_tag]} as a FOSS EZBake build target",
      :description  => description[:ezbake],
      :story_points => '1',
      :blocked_by   => ['puppetserver', 'puppetdb'],
    },
    {
      :short_name   => 'module_support',
      :project      => 'FM',
      :summary      => "Intention to support #{vars[:platform_tag]} as a master platform",
      :description  => description[:module_support],
    },
    {
      :short_name   => 'docs_support',
      :project      => 'DOC',
      :summary      => "Intention to support #{vars[:platform_tag]} as a master platform",
      :description  => description[:docs_support],
    },
  ]

  if vars[:foss_only] == "false"
    subtickets += [
      {
        :short_name   => 'puppet_agent',
        :project      => 'RE',
        :summary      => "Build and promote puppet-agent packages for #{vars[:platform_tag]} into PE #{vars[:pe_ver]}",
        :description  => description[:puppet_agent],
        :story_points => '2',
      },
      {
        :short_name   => 'pe_client_tools',
        :project      => 'RE',
        :summary      => "Build and promote pe-client-tools packages for #{vars[:platform_tag]} into PE #{vars[:pe_ver]}",
        :description  => description[:pe_client_tools],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'pe_r10k',
        :project      => 'RE',
        :summary      => "Build and promote pe-r10k packages for #{vars[:platform_tag]} into PE #{vars[:pe_ver]}",
        :description  => description[:pe_r10k],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'pe_puppetserver',
        :project      => 'SERVER',
        :summary      => "Update the pe-puppetserver ci-job-config entry to include #{vars[:platform_tag]} for PE #{vars[:pe_ver]}",
        :description  => description[:pe_puppetserver],
        :story_points => '2',
        :blocked_by   => ['puppet_agent', 'puppetserver'],
      },
      {
        :short_name   => 'pe_puppetdb',
        :project      => 'PDB',
        :summary      => "Update the pe-pdb ci-job-config entry to include #{vars[:platform_tag]} for PE #{vars[:pe_ver]}",
        :description  => description[:pe_puppetpb],
        :story_points => '2',
        :blocked_by   => ['puppet_agent', 'puppetdb'],
      },
      {
        :short_name   => 'pe_ezbake',
        :project      => 'EZ',
        :summary      => "Add #{vars[:platform_tag]} as a PE EZBake build target",
        :description  => description[:pe_ezbake],
        :story_points => '1',
        :blocked_by   => ['pe_puppetserver', 'pe_puppetdb'],
      },
      {
        :short_name   => 'pe_razor_server',
        :project      => 'RAZOR',
        :summary      => "Update the pe-razor-server ci-job-config entry to include #{vars[:platform_tag]} for PE #{vars[:pe_ver]}",
        :description  => description[:pe_razor_server],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'enterprise_dist',
        :project      => 'RE',
        :summary      => "Build, ship, and promote all packages required via enterprise-dist automation",
        :description  => description[:enterprise_dist],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'pper',
        :project      => 'RE',
        :summary      => "Build, ship, and promote pe-puppet-enterprise-release for #{vars[:platform_tag]} for into #{vars[:pe_ver]}",
        :description  => description[:enterprise_dist],
        :parent       => 'enterprise_dist',
      },
      {
        :short_name   => 'activemq',
        :project      => 'RE',
        :summary      => "Build, ship, and promote activemq for #{vars[:platform_tag]} for into #{vars[:pe_ver]}",
        :description  => description[:enterprise_dist],
        :parent       => 'enterprise_dist',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'nginx',
        :project      => 'RE',
        :summary      => "Build, ship, and promote nginx for #{vars[:platform_tag]} for into #{vars[:pe_ver]}",
        :description  => description[:enterprise_dist],
        :parent       => 'enterprise_dist',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'pe_java',
        :project      => 'RE',
        :summary      => "Build, ship, and promote pe-java for #{vars[:platform_tag]} for into #{vars[:pe_ver]}",
        :description  => description[:enterprise_dist],
        :parent       => 'enterprise_dist',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'postgres',
        :project      => 'RE',
        :summary      => "Build, ship, and promote postgres for #{vars[:platform_tag]} into #{vars[:pe_ver]}",
        :description  => description[:enterprise_dist],
        :parent       => 'enterprise_dist',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'bundler',
        :project      => 'RE',
        :summary      => "Build, ship, and promote bundler for #{vars[:platform_tag]} into #{vars[:pe_ver]}",
        :description  => description[:enterprise_dist],
        :parent       => 'enterprise_dist',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'console_services',
        :project      => 'RE',
        :summary      => "Build, ship, and promote console-services for #{vars[:platform_tag]} into #{vars[:pe_ver]}",
        :description  => description[:console_services],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'pe_installer',
        :project      => 'RE',
        :summary      => "Build, ship, and promote pe-installer for #{vars[:platform_tag]} into #{vars[:pe_ver]}",
        :description  => description[:pe_installer],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'pe_orchestration_services',
        :project      => 'RE',
        :summary      => "Build, ship, and promote pe-orechestration-services for #{vars[:platform_tag]} into #{vars[:pe_ver]}",
        :description  => description[:pe_orchestration_services],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'pe_puppet_license_cli',
        :project      => 'RE',
        :summary      => "Build, ship, and promote pe-puppet-license-cli for #{vars[:platform_tag]} into #{vars[:pe_ver]}",
        :description  => description[:pe_puppet_license_cli],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'pe_license',
        :project      => 'RE',
        :summary      => "Build, ship, and promote pe-license for #{vars[:platform_tag]} into #{vars[:pe_ver]}",
        :description  => description[:pe_license],
        :story_points => '2',
        :blocked_by   => ['puppet_agent'],
      },
      {
        :short_name   => 'compose',
        :project      => 'RE',
        :summary      => "Update the enterprise-dist compose pipeline for PE #{vars[:pe_ver]} to include #{vars[:platform_tag]}",
        :description  => description[:compose],
        :story_points => '2',
        :blocked_by   => ['enterprise_dist'],
      },
      {
        :short_name   => 'integration_pipelines',
        :project      => 'PE',
        :summary      => "Update the PE Integration Pipelines in ci-job-configs to include #{vars[:platform_tag]} in the PE #{vars[:pe_ver]} pipeline",
        :description  => description[:integration_pipeline],
        :story_points => '2',
        :blocked_by   => ['compose'],
      },
      {
        :short_name   => 'install_pe_meep',
        :project      => 'PE',
        :summary      => "Install PE #{vars[:pe_ver]} on #{vars[:platform_tag]} with Meep",
        :description  => description[:install_pe_meep],
        :story_points => '2',
        :blocked_by   => ['integration_pipelines'],
      },
      {
        :short_name   => 'install_pe_legacy',
        :project      => 'PE',
        :summary      => "Install PE #{vars[:pe_ver]} on #{vars[:platform_tag]} with the legacy installer",
        :description  => description[:install_pe_legacy],
        :story_points => '2',
        :blocked_by   => ['integration_pipelines'],
      },
      {
        :short_name   => 'uninstall_pe',
        :project      => 'PE',
        :summary      => "Uninstall PE #{vars[:pe_ver]} on #{vars[:platform_tag]}",
        :description  => description[:uninstall_pe],
        :story_points => '2',
        :blocked_by   => ['integration_pipelines', 'install_pe_meep', 'install_pe_legacy'],
      },
      {
        :short_name   => 'support_script',
        :project      => 'PE',
        :summary      => "Test Support Script for #{vars[:platform_tag]}",
        :description  => description[:support_script],
        :story_points => '2',
        :blocked_by   => ['uninstall_pe'],
      },
    ]
  end


  ## MAIN TICKET

  summary = "Add #{vars[:platform_tag]} as a supported master platform"
  description[:top_level_ticket] = <<-DOC
It has come time to add in support for #{vars[:platform_tag]}. This epic is meant to track the effort to
stand up build and test infrastructure for the new platform. Once that work has been completed, users may
see the new platform available through nightly builds. Otherwise, it will become available whenever the
next release happens.

This epic is only to add support for this platform in the server stack. The agent stack work for this
platform should have already happened in a separate epic.
DOC

  # Values for the main ticket
  parent_project  = 'RE'
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


    # Is this ticket a subtask with a parent ticket? If so, we need to figure out the parent key
    # and pass that information in during the ticket creation process
    if subticket[:parent] && !subticket[:epic_parent] && (!subticket[:type] || subticket[:type] == 'Sub-task')
      subticket[:parent] = subticket_hash[subticket[:parent]]['key']
      subticket[:type] = 'Sub-task'
      unless subticket[:parent].match(subticket[:project])
        fail "Subtickets must be in the same project as their parent ticket. Did you mean to have ticket ##{subticket[:index]} block #{subticket[:parent]}?"
      end
    elsif subticket[:epic_parent] && !subticket[:parent] && (!subticket[:type] || subticket[:type] != 'Sub-task' || subticket[:type] != 'Epic')
      subticket[:epic_parent] = subticket_hash[subticket[:epic_parent]]['key']
    else
      blocks << parent_key
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
Create tickets to build out the master stack for a new platform
EOS

  task :new_server_platform_tickets do
    vars = get_server_platform_ticket_vars
    jira = Pkg::Util::Jira.new(vars[:username], vars[:site])

    vars[:base64_encoding] = Pkg::Util.base64_encode("#{vars[:username]}:#{jira.client.options[:password]}")

    puts "Creating new platform tickets based on:"
    require 'pp'
    pp vars.select { |k, v| k != :password }

    create_server_platform_tickets(jira, vars)
  end
end
