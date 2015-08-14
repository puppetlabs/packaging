module Pkg::Util
  class Jira

    require 'json'

    attr_accessor :client

    # This class is a very thin wrapper around the jira library. For testability,
    # the small bit of logic that does some prep for the library or processing of its
    # output are extracted into a handful of class methods.

    def self.jira_client_options(username, site)
      {
        :username           => username,
        :site               => site,
        :context_path       => '',
        :auth_type          => :basic,
        :use_ssl            => true,
      }
    end

    def self.jira_project_name(projects, project)
      # projects is an array of objects with key and name methods
      projects.find { |p| p.key == project }.name
    end

    def self.jira_issue_fields(options_hash)

      # Check to ensure we have what we need to create a ticket
      fail "The following ticket options hash requires a summary\n\n#{options_hash}" unless options_hash[:summary]

      # build the fields hash describing the ticket

      # These are required for all tickets
      fields = {
          'summary'     => options_hash[:summary],
          'project'     => { 'key' => options_hash[:project] },
      }

      # The following are optional
      if options_hash[:description]
        fields['description'] = options_hash[:description]
      end
      if options_hash[:assignee]
        fields['assignee'] = { 'name' => options_hash[:assignee] }
      end
      if options_hash[:story_points]
        fields['customfield_10002'] = options_hash[:story_points].to_i
      end

      if options_hash[:components]
        fields['components'] = []
        options_hash[:components].each do |component|
          fields['components'] << { 'name' => component }
        end
      end

      # Default ticket type to 'Task' if it isn't already set
      if options_hash[:type]
        fields['issuetype'] = { 'name' => options_hash[:type] }
      else
        fields['issuetype'] = { 'name' => "Task" }
      end

      # If this is an epic, we need to add an epic name
      if options_hash[:type] == 'Epic'
        fields['customfield_10007'] = options_hash[:summary]
      end

      # If a ticket has a specified parent ticket, prefer that. The parent ticket *should* already
      # be linked to the main epic. Otherwise, we need to set it to have an epic_parent. This can
      # either be an epic linked to the main epic or the main epic itself.
      if options_hash[:parent]
        fail "A ticket with a parent must be classified as a Sub-ticket\n\n#{options_hash}" unless options_hash[:type] == 'Sub-task' || !options_hash[:type]
        fields['issuetype'] = { 'name' => "Sub-task" }
        fields['parent'] = { 'key' => options_hash[:parent] }
      elsif options_hash[:epic_parent]
        fail "This ticket cannot be a Sub-task of an epic\n\n#{options_hash}" if options_hash[:type] == 'Sub-task'
        fields['customfield_10006'] = options_hash[:epic_parent]
      end

      fields
    end

    def self.get_auth_vars
      vars = {}
      vars[:site]     = ENV['JIRA_INSTANCE'] || 'https://tickets.puppetlabs.com'
      vars[:username] = Pkg::Util.get_var("JIRA_USER")
      vars
    end

    def self.link_issues(inwardIssue, outwardIssue, site, authentication, type = 'Blocks')
      data = {
        'type'          => { 'name' => type },
        'inwardIssue'   => { 'key'  => inwardIssue },
        'outwardIssue'  => { 'key'  => outwardIssue },
      }

      uri = "#{site}:443/rest/api/2/issueLink"
      form_data = ['-D-',
                   '-X POST',
                   "--data '#{data.to_json}'",
                   "-H 'Authorization: Basic #{authentication}'",
                   "-H 'Content-Type: application/json'"]
      options = { :quiet => true }
      Pkg::Util::Net.curl_form_data(uri, form_data, options)
    rescue Exception => e
      fail "Cannot create link between #{inwardIssue} and #{outwardIssue}"
    end

    # Future improvement, exception handling and more helpful error messages
    #
    def initialize(username, site)
      # This library uses the gem called 'jira-ruby' which provides the library 'jira'.
      # Not to be confused with the gem called 'jira'. Be careful out there.
      Pkg::Util.require_library_or_fail('jira', 'jira-ruby')

      # Construct a jira client
      options = self.class.jira_client_options(username, site)

      # retrieve password without revealing it
      puts "Logging in to #{site} as #{options[:username]}"
      print "Password please: "
      options[:password] = Pkg::Util.get_input(false)
      puts "\nOkay trying to log in to #{site} as #{options[:username]} ..."

      options[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_PEER
          # only get OpenSSL through the jira library so leave it out of the class method
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
      self.class.jira_project_name(@client.Project.all, project)
    end

    def create_issue(options_hash)
      fields = self.class.jira_issue_fields(options_hash)

      issue = @client.Issue.build
      issue.save!({ 'fields' => fields })

      return issue.key, issue.id
    rescue Exception => e
      fail "Cannot create Jira Ticket with fields #{fields}"
    end
  end
end
