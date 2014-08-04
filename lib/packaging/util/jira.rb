module Pkg::Util
  class Jira

    # This class is a very thin wrapper around the jira library. For testability,
    # the small bit of logic that does some prep for the library or processing of its
    # output are extracted into a handful of class methods.

    def self.jira_client_options(username, password, site)
      {
        :username           => username,
        :password           => password,
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

    # Future improvement, exception handling and more helpful error messages
    #
    def initialize(username, password, site)
      # This library uses the gem called 'jira-ruby' which provides the library 'jira'.
      # Not to be confused with the gem called 'jira'. Be careful out there.
      Pkg::Util.require_library_or_fail('jira', 'jira-ruby')

      # Construct a jira client
      options = self.class.jira_client_options(username, password, site)
      options[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_PEER
          # only get OpenSSL through the jira library so leave it out of the class method
      @client = JIRA::Client.new(options)
    end

    def project?(project)
      @client.Project.find(project)
    rescue
      raise "Could not find project: #{project}"
    end

    def user?(user)
      @client.User.find(user)
    rescue
      raise "Could not find user: #{user}"
    end

    def project_name(project)
      self.class.jira_project_name(@client.Project.all, project)
    end

    def create_issue(summary, description, project, parent, assignee)
      fields = self.class.jira_issue_fields(summary, description, project,
                                            parent, assignee)

      issue = @client.Issue.build
      issue.save!({ 'fields' => fields })

      # fetch the issue back so we can report the key and id
      issue.fetch

      return issue.key, issue.id
    end
  end
end
