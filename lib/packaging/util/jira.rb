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

    def self.jira_issue_fields(summary, description, project, parent, assignee)
      # build the fields hash describing the ticket
      fields = {
          'summary'     => summary,
          'description' => description,
          'project'     => { 'key' => project },
          'issuetype'   => { 'name' => parent ? "Sub-task" : "Task" },
          'assignee'    => { 'name' => assignee },
      }
      if parent
        fields['parent'] = { 'id' => parent }
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

    def create_issue(summary, description, project, parent, assignee)
      fields = self.class.jira_issue_fields(summary, description, project,
                                            parent, assignee)

      issue = @client.Issue.build
      issue.save!({ 'fields' => fields })

      return issue.key, issue.id
    rescue Exception => e
      fail "Cannot create Jira Ticket with fields #{fields}"
    end
  end
end
