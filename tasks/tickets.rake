# This rake task creates tickets in jira for a release. Typical usage
# would start in a clone of a foss project like puppet, and after
# running 'rake package:bootstrap', tickets could be created like so:
#
#    rake pl:tickets BUILDER=melissa DEVELOPER=kylo WRITER=nickf RELEASE=3.5.0-rc4 \
#        DATE=2014-04-01 JIRA_USER=kylo PROJECT=PUP
#
# The JIRA_USER parameter is used to login to jira to create the tickets. You will
# be prompted for a password. It will not be displayed.
#
# The BUILDER/DEVELOPER/WRITER params are checked against a known list of jira user
# ids. The Jira project is selected based on the foss project this is run from.
#

class Jira

  # Future improvement, exception handling and more helpful error messages
  #
  def initialize(username, password, site)
    require_library_or_fail('jira', 'jira-ruby')

    # Jira client options
    options = {
                :username           => username,
                :password           => password,
                :site               => site,
                :context_path       => '',
                :auth_type          => :basic,
                :use_ssl            => true,
                :ssl_verify_mode    => OpenSSL::SSL::VERIFY_PEER,
              }

    # Create a Jira client and find the *Jira* project name for the summary
    @client = JIRA::Client.new(options)
  end

  def project?(project)
    @client.Project.find(project)
  rescue
    fail "Could not find project: #{project}"
  end

  def user?(user)
    @client.User.find(user)
  rescue
    fail "Could not find user: #{user}"
  end

  def project_name(project)
    projects = @client.Project.all
    projects.find { |p| p.key == project }.name
  end

  def create_issue(summary, description, project, parent, assignee)

    # build the fields hash describing the ticket
    fields = {
        'summary'     => summary,
        'description' => summary,
        'project'     => { 'key' => project},
        'issuetype'   => { 'name' => parent ? "Sub-task" : "Task" },
        'assignee'    => { 'name' => assignee },
    }
    if parent
      fields['parent'] = { 'id' => parent }
    end

    issue = @client.Issue.build
    issue.save!( {'fields' => fields } )

    # fetch the issue back so we can report the key and id
    issue.fetch

    return issue.key, issue.id
  end
end

def get_password(site, user)
  require 'io/console'
  puts  "Logging in to #{site} as #{user}"
  print "Password please: "
  password = STDIN.noecho(&:gets).chomp
  puts "\nOkay trying to log in to #{site} as #{user} ..."
  password
end

def get_vars
  vars = {}

  # roles
  vars[:builder]   = Pkg::Util.get_var("BUILDER")
  vars[:developer] = Pkg::Util.get_var("DEVELOPER")
  vars[:writer]    = Pkg::Util.get_var("WRITER")

  # project and release
  vars[:release]   = Pkg::Util.get_var("RELEASE")
  vars[:project]   = Pkg::Util.get_var("PROJECT")
  vars[:date]      = Pkg::Util.get_var("DATE")

  # Jira authentication - do this after validating other params, so user doesn't need to
  # enter password only to find out they typo'd one of the above
  vars[:site]      = 'https://tickets.puppetlabs.com'
  vars[:username]  = Pkg::Util.get_var("JIRA_USER")
  vars[:password]  = get_password(vars[:site], vars[:username])

  vars
end

def get_jira_client(vars)
  Jira.new(vars[:username], vars[:password], vars[:site])
end

def validate_vars(jira, vars)
  jira.project?(vars[:project])
  jira.user?   (vars[:builder])
  jira.user?   (vars[:writer])
  jira.user?   (vars[:developer])
end

def create_tickets(jira, vars)
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
      :description => 'Developer provides the SHA. For puppet, don\'t forget the msi packages.',
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
      :projects    => ['PDB'],  # Only PDB has this step
      :summary     => 'Update dujour to notify users to use #{vars[:release]}',
      :description => '',
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Close all resolved tickets in Jira',
      :description => '',
      :assignee    => vars[:developer]
    },
  ]

  # Use the human-friendly project name in the summary
  project_name = jira.project_name(vars[:project])
  summary = "#{project_name} #{vars[:release]} #{vars[:date]} Release"

  # Values for the main ticket
  project  = vars[:project]
  assignee = vars[:developer]

  # Create the main ticket
  key, parent_id = jira.create_issue(summary,
                                     summary,
                                     project,
                                     nil,     # no parent id
                                     assignee)

  puts "Main release ticket: #{key} (#{assignee}) - #{summary}"

  # Create subtasks for each step of the release process
  subticket_idx = 1
  subtickets.each { |subticket|

    next if subticket[:projects] && !subticket[:projects].include?(vars[:project])

    key, _ = jira.create_issue(subticket[:summary],
                               subticket[:description],
                               project,
                               parent_id,
                               subticket[:assignee])

    puts "\tSubticket #{subticket_idx.to_s.rjust(2)}: #{key} (#{subticket[:assignee]}) - #{subticket[:summary]}"

    subticket_idx += 1
  }
end

namespace :pl do
  desc "Make release tickets in jira for this project"
  task :tickets do
    vars = get_vars
    jira = get_jira_client(vars)
    validate_vars(jira, vars)

    puts "Creating tickets based on:"
    require 'pp'
    pp vars.select { |k,v| k != :password }

    create_tickets(jira, vars)
  end
end

