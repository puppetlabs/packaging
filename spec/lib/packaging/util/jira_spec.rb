# -*- ruby -*-
require 'spec_helper'
require 'packaging/util/jira'

describe Pkg::Util::Jira do
  it "should build an expected set of client options" do
    options = described_class.jira_client_options("user", "http://devnull.tld")
    expect(options[:username]).to eq("user")
    expect(options[:site]).to eq("http://devnull.tld")
  end

  it "should extract a project name from the project list" do
    Project = Struct.new(:key, :name)
    projects = [Project.new("PUP", "PUP"), Project.new("FOO", "BAR")]

    expect(described_class.jira_project_name(projects, "PUP")).to eq("PUP")
    expect(described_class.jira_project_name(projects, "FOO")).to eq("BAR")
  end

  it "should build a parent ticket's fields" do
    fields = described_class.jira_issue_fields({:summary => "summary",
                                               :description => "desc",
                                               :project => "PUP",
                                               :parent => nil,
                                               :assignee => "ivy"})

    expect(fields['summary']).to eq("summary")
    expect(fields['description']).to eq("desc")
    expect(fields['project']['key']).to eq("PUP")
    expect(fields['issuetype']['name']).to eq("Task")
    expect(fields['assignee']['name']).to eq("ivy")
    expect(fields['parent']).to eq(nil)
  end

  it "should build a subtask ticket's fields" do
    fields = described_class.jira_issue_fields({:summary => "sub summary",
                                               :description => "sub desc",
                                               :project => "PUP",
                                               :parent => "PUP-123",
                                               :assignee => "bean"})

    expect(fields['summary']).to eq("sub summary")
    expect(fields['description']).to eq("sub desc")
    expect(fields['project']['key']).to eq("PUP")
    expect(fields['issuetype']['name']).to eq("Sub-task")
    expect(fields['assignee']['name']).to eq("bean")
    expect(fields['parent']['key']).to eq("PUP-123")
  end
end
