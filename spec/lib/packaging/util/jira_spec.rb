# -*- ruby -*-
require 'spec_helper'
require 'packaging/util/jira'

describe Pkg::Util::Jira do
  it "should build an expected set of client options" do
    options = described_class.jira_client_options("user", "password", "http://devnull.tld")
    expect(options[:username]).to eq("user")
    expect(options[:password]).to eq("password")
    expect(options[:site]).to eq("http://devnull.tld")
  end

  it "should extract a project name from the project list" do
    Project = Struct.new(:key, :name)
    projects = [Project.new("PUP", "PUP"), Project.new("FOO", "BAR")]

    expect(described_class.jira_project_name(projects, "PUP")).to eq("PUP")
    expect(described_class.jira_project_name(projects, "FOO")).to eq("BAR")
  end

  it "should build a parent ticket's fields" do
    fields = described_class.jira_issue_fields("summary",
                                               "desc",
                                               "PUP",
                                               nil,
                                               "ivy")

    expect(fields['summary']).to eq("summary")
    expect(fields['description']).to eq("desc")
    expect(fields['project']['key']).to eq("PUP")
    expect(fields['issuetype']['name']).to eq("Release")
    expect(fields['assignee']['name']).to eq("ivy")
    expect(fields['parent']).to eq(nil)
  end

  it "should build a subtask ticket's fields" do
    fields = described_class.jira_issue_fields("sub summary",
                                               "sub desc",
                                               "PUP",
                                               42,
                                               "bean")

    expect(fields['summary']).to eq("sub summary")
    expect(fields['description']).to eq("sub desc")
    expect(fields['project']['key']).to eq("PUP")
    expect(fields['issuetype']['name']).to eq("Sub-task")
    expect(fields['assignee']['name']).to eq("bean")
    expect(fields['parent']['id']).to eq(42)
  end
end
