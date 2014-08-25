# -*- ruby -*-
require 'spec_helper'

describe "Pkg::Util::Jenkins" do
  let(:build_host) {"Jenkins-foo"}
  let(:name) {"job-foo"}
  around do |example|
    old_build_host = Pkg::Config.jenkins_build_host
    Pkg::Config.jenkins_build_host = build_host
    example.run
    Pkg::Config.jenkins_build_host = old_build_host
  end

  describe "#create_jenkins_job" do
    let(:xml_file) {"bar.xml"}

    it "should call curl_form_data with the correct arguments" do
      Pkg::Util::Net.should_receive(:curl_form_data).with("http://#{build_host}/createItem?name=#{name}", ["-H", '"Content-Type: application/xml"', "--data-binary", "@#{xml_file}"])
      Pkg::Util::Jenkins.create_jenkins_job(name, xml_file)
    end
  end

  describe "#jenkins_job_exists?" do

    it "should call curl_form_data with correct arguments" do
      Pkg::Util::Net.should_receive(:curl_form_data).with("http://#{build_host}/job/#{name}/config.xml", ["--silent", "--fail"], :quiet => true)
      Pkg::Util::Jenkins.jenkins_job_exists?(name)
    end

    it "should return false on job not existing" do
      Pkg::Util::Net.should_receive(:curl_form_data).with("http://#{build_host}/job/#{name}/config.xml", ["--silent", "--fail"], :quiet => true).and_return(false)
      Pkg::Util::Jenkins.jenkins_job_exists?(name).should be_false
    end

    it "should return true when job exists" do
      Pkg::Util::Net.should_receive(:curl_form_data).with("http://#{build_host}/job/#{name}/config.xml", ["--silent", "--fail"], :quiet => true).and_return(true)
      Pkg::Util::Jenkins.jenkins_job_exists?(name).should be_true
    end
  end
end
