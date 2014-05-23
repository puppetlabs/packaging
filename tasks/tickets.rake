# This rake task creates tickets in jira for a release.
#

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

def validate_vars(jira, vars)
  jira.project?(vars[:project])
  jira.user?   (vars[:builder])
  jira.user?   (vars[:writer])
  jira.user?   (vars[:developer])
end

def create_tickets(jira, vars)
  description = {}
  description[:code_ready] = <<-DOC
All tests (spec, acceptance) should be passing on all platforms for both stable & master.

  * If a new platform has been added, make sure that platform has acceptance testing, new features have decent coverage, etc. etc.
  * If the release is going to be cut from a sha, rather than the head of a branch, make sure that sha specifically has gone through spec/acceptance/etc. tests
  * Move all items that should be moved from Ready for CI to Ready for Review

Have all tickets been resolved (passed Functional Review)? If not please add any missing tickets to the current sprint's board.

NOTE: This link may not work properly for RC releases. Edit it to remove the "-rc#".
https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20#{vars[:project]}%20AND%20resolution%20%3D%20Unresolved%20AND%20fixVersion%20%3D%20%22#{vars[:release]}%22
DOC

  description[:jira_tickets_for_commit] = <<-DOC
Ensure all tickets referenced in the commit log have a bug targeted at the release

  * git log <old tag>..<new tag>
  * look through, and make sure that if there is a JIRA ticket number referenced in any of the commits, that ticket is targeted at the release
  * Also, make sure the code itself is sane, that you understand why the change was made, etc. etc.
  * [ticketmatch.rb script|https://gist.github.com/hlindberg/9520023] is a ruby script that helps with "Is there a JIRA ticket targeted at the release for every commit?" and "Is there a commit for every JIRA ticket targeted at the release?" (it beats doing it manually, but requires manual steps and hacking the script for the specific release)
DOC

  description[:git_commits_for_tickets] = <<-DOC
Ensure all tickets targeted at the release have a corresponding commit
  * git log <old tag>..<new tag>
  * This time, look through tickets targeted at this release in JIRA, and compare it to the commit log, looking for the corresponding numbers
  * [ticketmatch.rb script|https://gist.github.com/hlindberg/9520023] is a ruby script that helps with "Is there a JIRA ticket targeted at the release for every commit?" and "Is there a commit for every JIRA ticket targeted at the release?" (it beats doing it manually, but requires manual steps and hacking the script for the specific release)
DOC

  description[:update_version_source] = <<-DOC
Bump VERSION in lib/{#project}/version.rb to correct version.

  * Commit the updated version file.
    * e.g) commit -m "(packaging) Update FACTERVERSION to 1.7.3-rc1".
  * If any merging needs to happen (i.e. master into stable/stable into master), it can now happen (different subtask).
  * Once this is done, hand the SHA to be built to RelEng to be tagged.

Dependencies:
  * Is the code ready for release?
  * Is there a commit for every JIRA ticket targeted at the release?
DOC

  description[:merge_to_stable] = <<-DOC
For some releases, the code base will need to be merged down to stable.

*NOTE:* This is usually only during a z-rc1 release, but even then it may have already been done. If it doesn't apply, close this ticket.


Assuming you have origin (your remote) and upstream (puppetlabs remote), the commands will look something like this:
{noformat}
git fetch upstream
git rebase upstream/master

git checkout stable
git rebase upstream/stable

git merge master --no-ff --log
{noformat}

Once that looks good:
{noformat}
git push origin
git push upstream
{noformat}

After merging to stable, the jobs on jenkins may require updates (spec, acceptance, etc) when you merge master into stable. Please ensure that the jenkins jobs are updated if necessary.

Dependencies:
  * Is the code ready for release?
  * Is there a commit for every JIRA ticket targeted at the release?
  * Update version number in source
DOC

  description[:jira_maintenance] = <<-DOC
This happens on Jira - we need to clean up the current release and prepare for the next release.
  * Mark the version that's going out as "Released" in the Project Admin -> Versions panel.
  * Create a version we can target future issues or issues that didn't make it into the current release.  (e.g. if we're releasing Facter 1.7.4, make sure there's a 1.7.5 version (or at least 1.7.x if there's isn't another bug release planned for the near future)
  * Create a public pair of queries for inclusion in the release notes/announcement. These allow easy tracking as new bugs come in for a particular version and allow everyone to see the list of changes slated for the next release (Paste their URLs into the "Release story" ticket):
    - 'project = XX AND affectedVersion = 'X.Y.Y', Save as "Introduced in X.Y.Y", click Details, add permission for Everyone
    - 'project = XX AND fixVersion = 'X.Y.Z', Save as "Fixes for X.Y.Z", click Details, add permission for Everyone
DOC

  description[:release_notes] = <<-DOC
Collaborating with product for release story

Dependencies:
  * Is there a JIRA ticket targeted at the release for every commit?
  * Is there a commit for every JIRA ticket targeted at the release?
DOC

  description[:tag_package] = <<-DOC
Tag and create packages

  * Developer provides the SHA - [~#{vars[:developer]}] - Please add the SHA as a comment (this should be the commit which contains the newly updated version.rb)
  * checkout the sha
    * NOTE: If this is a final release, make sure you're releasing only the code that already went through rc, so don't let any new code get into the final release
    * Make sure you are about to tag the correct thing
  * Create the tag e.g.) git tag -s -u {GPG key} -m "1.7.3-rc1" 1.7.3-rc1
    * You need to know the pass phrase for this to complete successfully. It's important that we make sure all releases are signed to verify authenticity.
    * DO NOT push the tag to the repo, keep it local only
  * `git describe` will show you the tag. Make sure you're building what you think you're building.
  * Make sure you look over the code that has changed since the previous release so we know what's going out the door.
  * run `rake package:implode package:bootstrap pl:jenkins:uber_build` when you've verified what version you're building (this uses the latest version of the packaging repo to build the packages).
  * If this is a puppet release, you have to build the windows msi. This is done using jenkins jobs on jenkins-legacy. You have to make sure you're targeting the correct versions of hiera, facter and puppet.
  * [~#{vars[:builder]}] please add a comment with location of packages.

For puppet, don't forget the msi packages. This usually comes after other smoke testing is going well since it does require the tag to be pushed live.

Dependencies:
  * Every ticket before this except for release notes.
DOC

  description[:smoke_test] = <<-DOC
Procedure may vary by project and point in the release cycle. Ask around.

In general this should happen on a variety of platforms, i.e. one or two each of kind of package we create (i.e., gem, dmg, msi, deb, rpm, etc).
If this is a final release then the previous RC (which should be identical to what is currently being released) will have gone through this testing. Lighter testing is acceptable.

  * Add a link to the Packages repository that you receive from the "Tag and create packages" subtask
  * Ping folks on your team for help with different platforms.
  * When you pick up a platform, please leave a comment below that you are testing it. When it looks good, leave another comment, preferably with a code snippet showing the commands executed and their output.
  * When all platforms picked have been smoke tested, move this ticket to done.

Example:
Smoke test platforms:
  * pick some platforms such as
  * RHEL 5/6/7
  * CentOS 5/6
  * Windows 2003/2008/2012
  * Debian 6/7/
  * Ubuntu 10.04/12.04/14.04

Smoke test procedure:
  * Start/stop/restart a master with the init scripts (on Debian try the passenger master)
  * Start/stop/restart an agent
  * Help/man
  * Write and run some manifests

Dependencies:
  * Tag and create packages
  * For Windows MSIs - Push tag
DOC

  description[:go_no_go] = <<-DOC
Get a yes/no for the release from dev, docs, product, qa, releng.

This meeting is informal, over chat, and usually happens right before packages are pushed.
Keep in mind we typically do not ship releases in the evening and we don't ship on Friday if the release is a final release.

Dependencies:
  * Smoke testing
DOC

  description[:push_tag] = <<-DOC
The development team is responsible for updating the stable/master branches as necessary.
This will be done after the version bump in version.rb.

Dependencies:
  * Go / No Go meeting (except where it's required to push the tag to build packages - MSIs)
DOC

  description[:push_packages] = <<-DOC
Push packages
  * run `rake pl:jenkins:uber_ship`
    * You will need the keys to the castle (aka the passphrase) for this to work.
    * Don't forget to make sure everything looks like it's in the correct folder, the pkgs dir has been cleared out, and that you are shipping for all expected platforms.
    * Get a *second set of RelEng eyes* on the packages that are about to be shipped to make sure everything looks a-okay.
    * If you're shipping a gem you need to make sure you have a rubygems account, are an owner of that project, and have a gem config file.
    * If you're shipping puppet you need to sign the MSI file for Windows. This is a manual process and the ship task doesn't ship or build the msi so talk to Moses or [~matthaus] for more details. This file also needs to be manually signed.

Dependencies:
  * Go / No Go meeting (Status - Ship it!)
DOC

  description[:update_downloads] = <<-DOC
Update downloads page
  * Update misc/download-options to reflect the new builds you just pushed and also make sure they're displayed. It's a good idea to make sure this looks like it's supposed to

NOTE: this page will hopefully be deprecated soon. The idea is that docs with update their documentation to include "latest release version" and where to download files. This page will then be changed to redirect to docs.puppetlabs.com and will no longer need updating.

Dependencies:
  * Go / No Go meeting (Status - Ship it!)
DOC

  description[:push_docs] = <<-DOC
Push the documentation updates to docs.puppetlabs.com.

Dependencies:
  * Go / No Go meeting (Status - Ship it!)
DOC

  description[:send_announcements] = <<-DOC
  * Update the release google document (ask around for location).
  * Send the drafted release notes email.
    * If final send to puppet-announce and specific distribution lists (e.g. puppet to puppet-users & puppet-dev).
    * If RC only send to the specific distribution lists.
  * Make a PSA on IRC letting those kiddos know about the new release.
    * Something along the lines of "PSA: facter 1.7.3-rc1 now available"

Dependencies:
  * Prepare long form release notes and short form release story
  * Packages pushed
DOC

  description[:update_dujour] = <<-DOC
Update dujour to notify users to use #{vars[:release]}.

Dependencies:
  * Packages pushed
DOC

  description[:close_tickets] = <<-DOC
Close any tickets that have been resolved for the release.

NOTE: This link may not work properly for RC releases. Edit it to remove the "-rc#".
https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20#{vars[:project]}%20AND%20resolution%20%3D%20Fixed%20AND%20fixVersion%20%3D%20%22#{vars[:release]}%22%20AND%20status%20%3D%20Resolved

There is a bulk edit at the top (a gear with the word "Tools"). Should you decide to take this route:
  * Select Bulk Change - All # issues
  * Step 1 - choose all relevant issues (likely all of them)
  * Step 2 - Select "Transition Issues"
  * Step 3 - Select "Closed"
  * Step 4 - Select "Fixed" in Change Resolution.
  * View what is about to change and confirm it. Then commit the change.

Dependencies:
  * Packages pushed
DOC

  # The subtickets to create for the individual tasks
  subtickets =
  [
    {
      :summary     => 'Is the code ready for release?',
      :description => description[:code_ready],
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Is there a JIRA ticket targeted at the release for every commit?',
      :description => description[:jira_tickets_for_commit],
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Is there a commit for every JIRA ticket targeted at the release?',
      :description => description[:git_commits_for_tickets],
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Update version number in source',
      :description => description[:update_version_source],
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Merge master into stable',
      :description => description[:merge_to_stable],
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Is the Jira tidy-up done for this release and prepared for the next one?',
      :description => description[:jira_maintenance],
     :assignee    => vars[:developer]
    },
    {
      :summary     => 'Prepare long form release notes and short form release story',
      :description => description[:release_notes],
      :assignee    => vars[:writer]
    },
    {
      :summary     => 'Tag the release and create packages',
      :description => description[:tag_package],
      :assignee    => vars[:builder]
    },
    {
      :summary     => 'Smoke test packages',
      :description => description[:smoke_test],
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Go/no-go meeting',
      :description => description[:go_no_go],
      :assignee    => vars[:developer]
    },
    {
        :summary     => 'Push tag',
        :description => description[:push_tag],
        :assignee    => vars[:builder]
    },
    {
      :summary     => 'Packages pushed',
      :description => description[:push_packages],
      :assignee    => vars[:builder]
    },
    {
      :summary     => 'Update the downloads page',
      :description => description[:update_downloads],
      :assignee    => vars[:builder]
    },
    {
        :summary     => 'Docs pushed',
        :description => description[:push_docs],
        :assignee    => vars[:writer]
    },
    {
      :summary     => 'Send out announcements',
      :description => description[:send_announcements],
      :assignee    => 'eric.sorenson'
    },
    {
      :projects    => ['PDB'],  # Only PDB has this step
      :summary     => 'Update dujour to notify users to use #{vars[:release]}',
      :description => description[:update_dujour],
      :assignee    => vars[:developer]
    },
    {
      :summary     => 'Close all resolved tickets in Jira',
      :description => description[:close_tickets],
      :assignee    => vars[:developer]
    },
  ]

  # Use the human-friendly project name in the summary
  project_name = jira.project_name(vars[:project])
  summary = "#{project_name} #{vars[:release]} #{vars[:date]} Release"
  description[:top_level_ticket] = <<-DOC
#{summary}

When working through this ticket, add it to the board and then keep it in the Ready for Engineering column.
Move the subtasks to In Progress when you are working on them and Resolved when you have completed them.
In general subtasks should only be moved to Ready for Engineering when they are ready to be worked on. For some assignees this is their cue to start working on release-related items.

 * The first set of tickets are assigned to the developer, those can all be converted to Ready for Engineering and you can start working through them.
 * Only when those are done should you move the "Prepare notes" and "Tag release/create packages" tasks to Ready for Engineering. Ping those assigned to move forward.
 * When you hear back for "Tag Release/create packages", you should move "Smoke test packages" to Ready for Engineering or In Progress if you are ready.
DOC

  # Values for the main ticket
  # Note: use the 're' user for the main ticket to get notifications
  # to the Release Engineering team
  project  = vars[:project]
  assignee = 're'

  # Create the main ticket
  key, parent_id = jira.create_issue(summary,
                                     description[:top_level_ticket],
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
  desc <<-EOS
Make release tickets in JIRA for this project.
Tickets are created by specifying a number of environment variables, e.g.:

    rake pl:tickets BUILDER=melissa DEVELOPER=kylo WRITER=nickf RELEASE=3.5.0-rc4
        DATE=2014-04-01 JIRA_USER=kylo PROJECT=PUP

The BUILDER/DEVELOPER/WRITER params must be valid jira usernames.

The RELEASE param is a freeform string, no validation is done against it.

The DATE param is a predicted date that this release ticket will be started. This
  is a hint to Release Engineering about when to prep for the release, but not a
  binding contract to release on that date.

The PROJECT param must be a valid jira project name; tickets will be created in this project.

The JIRA_USER parameter is used to login to jira to create the tickets. You will
  be prompted for a password. It will not be displayed.
EOS

  task :tickets do
    vars = get_vars
    jira = Pkg::Util::Jira.new(vars[:username], vars[:password], vars[:site])
    validate_vars(jira, vars)

    puts "Creating tickets based on:"
    require 'pp'
    pp vars.select { |k,v| k != :password }

    create_tickets(jira, vars)
  end
end

