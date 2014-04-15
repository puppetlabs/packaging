module Pkg::Util
  class Jira

    # Future improvement, exception handling and more helpful error messages
    #
    def initialize(username, password, site)
      Pkg::Util.require_library_or_fail('jira', 'jira-ruby')

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

end
