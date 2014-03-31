# This rake task creates tickets in jira for a release. Typical usage
# would start in a clone of a foss project like puppet, and after
# running 'rake package:bootstrap', tickets could be created like so:
#
#    rake pl:tickets BUILDER=melissa DEVELOPER=kylo WRITER=nickf RELEASE=3.5.0-rc4
#
# The BUILDER/DEVELOPER/WRITER params are checked against a known list of jira user
# ids. The Jira project is selected based on the foss project this is run from.
#
# A note on authentication: the tickets will be created by the gepetto-bot
# account. You will need the current password for that account in the environment
# variable: GEPETTO_BOT_PASSWORD.
#

def check_for_jira_gem
  begin
    require 'jira'
  rescue LoadError
    fail "Be sure to 'gem install jira-ruby' to use this rake task"
  end
end

def get_var(var)
  check_var(var, ENV[var])
  ENV[var]
end

def get_project
  # get name of the git repository that packaging is cloned within
  project = Pkg::Util::Version.git_project_name

  known_git_projects = {
    "puppet"     => "PUP",
    "puppetdb"   => "PDB",
    "facter"     => "FACT",
    "hiera"      => "HI",
    "classifier" => "NC"
  }

  known_git_projects[project]
end

def get_vars
  vars = {}

  # Jira authentication
  vars[:username]  = "gepetto-bot"
  vars[:password]  = get_var("GEPETTO_BOT_PASSWORD")
  vars[:site]      = 'https://tickets.puppetlabs.com'

  # roles
  vars[:builder]   = get_var("BUILDER")
  vars[:developer] = get_var("DEVELOPER")
  vars[:writer]    = get_var("WRITER")

  # project and release
  vars[:release]   = get_var("RELEASE")
  vars[:project]   = ENV["PROJECT"] || get_project

  # validate the parameters where we have known lists
  known_projects = ['FACT', 'HI', 'PDB', 'PUP', 'NC']
  known_devs     = ['adrien', 'andy', 'dan.lidral-porter', 'ethan', 'henrik.lindberg', 'josh', 'joshua.partlow', 'ken', 'kylo', 'patrick', 'peter.huene', 'rob', 'ryan.senior']
  known_builders = ['matthaus', 'melissa', 'ryan.mckern']
  known_writers  = ['justin.holguin', 'nickf']

  if not known_projects.include? vars[:project]
    fail "Project #{vars[:project]}? Never heard of it. Must be one of #{known_projects.join(', ')}"
  end

  if not known_builders.include? vars[:builder]
    fail "Build Engineer must be one of #{known_builders.join(', ')}"
  end

  if not known_devs.include? vars[:developer]
    fail "Developer must be one of #{known_devs.join(', ')}"
  end

  if not known_writers.include? vars[:writer]
    fail "Wordsmith must be one of #{known_writers.join(', ')}"
  end

  vars
end

def create_tickets(vars)
  # The subtickets to create for the individual tasks
  subtickets =
  [
    {
      :summary     => 'Ensure tests are passing',
      :description => 'All tests (spec, acceptance) should be passing on all platforms.',
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Is there a bug targeted at the release for every commit?',
      :description => '',
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Is there a commit for every bug targeted at the release?',
      :description => '',
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Is a new version created for the next version in the series?',
      :description => '',
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Prepare long form release notes and short form release story',
      :description => 'Collaborating with product for release story',
      :assignee    => vars[:writer]
    },
    {
      :summary     => 'Update version number',
      :description => '',
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Tag the release and create packages',
      :description => 'Developer provides the SHA',
      :assignee    => vars[:builder]
    },
    {
      :summary     => 'Smoke test packages',
      :description => 'Procedure may vary by project and point in the release cycle. Ask around.',
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Go/no-go meeting',
      :description => 'Should include: dev, docs, product, qa, releng',
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Docs pushed',
      :description => '',
      :assignee    => vars[:writer]
    },
    {
      :summary     => 'Packages pushed',
      :description => '',
      :assignee    => vars[:builder]
    },
    {
      :summary     => 'Push tag',
      :description => '',
      :assignee    => vars[:builder]
    },
    {
      :summary     => 'Update the downloads page',
      :description => '',
      :assignee    => vars[:builder]
    },
    {
      :summary     => 'Send out announcements',
      :description => '',
      :assignee    => 'eric.sorenson'
    },
    {
      :summary     => 'Close all resolved tickets in Jira',
      :description => '',
      :assignee    => vars[:developer]
    },
  ]

  # Jira client options
  options = {
              :username           => vars[:username],
              :password           => vars[:password],
              :site               => vars[:site],
              :context_path       => '',
              :auth_type          => :basic,
              :use_ssl            => true,
              :ssl_verify_mode    => OpenSSL::SSL::VERIFY_PEER,
            }

  # Create a Jira client and find the *Jira* project name for the summary
  client = JIRA::Client.new(options)
  projects = client.Project.all
  project_name = projects.find { |p| p.key == vars[:project]  }
  name = project_name.name
  summary = "#{name} #{vars[:release]}"

  # Create the main ticket
  issue = client.Issue.build
  issue.save!( {'fields' => {
      'summary'     => "#{summary} Release",
      'description' => "#{summary} Release",
      'project'     => { 'key' => "#{vars[:project]}" },
      'issuetype'   => { 'name' => "Task" },
      'assignee'    => { 'name' => vars[:developer]}
      } } )
  issue.fetch
  puts "Main release ticket: #{issue.key} (#{issue.assignee.name}) - #{issue.summary}"
  parent_id = issue.id

  # Create subtasks for each step of the release process
  subticket_idx = 1
  subtickets.each { |subticket|

    issue2 = client.Issue.build

    subticket_fields = {'fields' => {
      'summary'     => subticket[:summary],
      'description' => subticket[:description],
      'project'     => { 'key' => "#{vars[:project]}" },
      'parent'      => { 'id' => parent_id },
      'issuetype'   => { 'name' => 'Sub-task'},
      'assignee'    => { 'name' => subticket[:assignee]}
      } }

    issue2.save!(subticket_fields)
    issue2.fetch
    puts "\tSubticket #{subticket_idx.to_s.rjust(2)}: #{issue2.key} (#{subticket[:assignee]}) - #{subticket[:summary]}"

    subticket_idx += 1
  }
end

namespace :pl do
  desc "Make release tickets in jira for this project"
  task :tickets do
    check_for_jira_gem

    vars = get_vars
    puts "Creating tickets based on:"
    require 'pp'
    pp vars

    create_tickets(vars)
  end
end

