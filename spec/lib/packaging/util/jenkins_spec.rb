# -*- ruby -*-
require 'spec_helper'

describe Pkg::Util::Jenkins do
  let(:build_host) {'Jenkins-foo'}
  let(:name) {'job-foo'}
  around do |example|
    old_build_host = Pkg::Config.jenkins_build_host
    Pkg::Config.jenkins_build_host = build_host
    example.run
    Pkg::Config.jenkins_build_host = old_build_host
  end

  describe '#create_jenkins_job' do
    let(:xml_file) {'bar.xml'}

    it 'should call curl_form_data with the correct arguments' do
      expect(Pkg::Util::Net)
        .to receive(:curl_form_data)
              .with("http://#{build_host}/createItem?name=#{name}", ["-H", '"Content-Type: application/xml"', "--data-binary", "@#{xml_file}"])
      Pkg::Util::Jenkins.create_jenkins_job(name, xml_file)
    end
  end

  describe '#jenkins_job_exists?' do
    it 'should call curl_form_data with correct arguments' do
      expect(Pkg::Util::Net)
        .to receive(:curl_form_data)
              .with("http://#{build_host}/job/#{name}/config.xml", ["--silent", "--fail"], :quiet => true).and_return(['output', 0])
      expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
      Pkg::Util::Jenkins.jenkins_job_exists?(name)
    end

    it 'should return false on job not existing' do
      expect(Pkg::Util::Net).to receive(:curl_form_data).with("http://#{build_host}/job/#{name}/config.xml", ["--silent", "--fail"], :quiet => true).and_return(['output', 1])
      expect(Pkg::Util::Execution).to receive(:success?).and_return(false)
      expect(Pkg::Util::Jenkins.jenkins_job_exists?(name)).to be false
    end

    it 'should return false if curl_form_data raised a runtime error' do
      expect(Pkg::Util::Net).to receive(:curl_form_data).with("http://#{build_host}/job/#{name}/config.xml", ["--silent", "--fail"], :quiet => true).and_return(false)
      expect(Pkg::Util::Jenkins.jenkins_job_exists?(name)).to be false
    end

    it 'should return true when job exists' do
      expect(Pkg::Util::Net).to receive(:curl_form_data).with("http://#{build_host}/job/#{name}/config.xml", ["--silent", "--fail"], :quiet => true).and_return(['output', 0])
      expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
      expect(Pkg::Util::Jenkins.jenkins_job_exists?(name)).to be true
    end
  end

  describe '#poll_jenkins_job' do
    let(:job_url) { 'http://cat.meow/' }
    let(:build_url) { "#{job_url}/1" }
    let(:result) { 'SUCCESS' }
    let(:job_hash) { {'lastBuild' => { 'url' => build_url } }}
    let(:build_hash) { {'result' => result, 'building' => false } }

    before :each do
      allow(subject).to receive(:get_jenkins_info).with(job_url).and_return(job_hash)
      allow(subject).to receive(:wait_for_build).with(build_url).and_return(build_hash)
    end

    context 'when polling the given url' do
      it 'return the resulting build_hash when build completes successfully' do
        subject.poll_jenkins_job(job_url)
      end
    end
  end

  describe '#wait_for_build' do
    let(:job_url) { 'http://cat.meow/' }
    let(:build_url) { "#{job_url}/1" }
    let(:build_hash) { {'building' => false } }

    context 'when waiting for the given build to finish' do
      it 'return the resulting build_hash when build completes successfully' do
        expect(subject).to receive(:get_jenkins_info).with(job_url).and_return(build_hash)
        subject.wait_for_build(job_url)
      end
    end
  end

  describe '#get_jenkins_info' do
    let(:url) { 'http://cat.meow/' }
    let(:uri) { URI(url) }
    let(:response) { double }
    let(:valid_json) { "{\"employees\":[
    {\"firstName\":\"John\", \"lastName\":\"Doe\"},
    {\"firstName\":\"Anna\", \"lastName\":\"Smith\"},
    {\"firstName\":\"Peter\", \"lastName\":\"Jones\"} ]}" }

    before :each do
      allow(response).to receive(:body).and_return valid_json
      allow(response).to receive(:code).and_return '200'
      expect(Pkg::Util::Jenkins).to receive(:URI).and_return(uri)
    end

    context 'when making HTTP GET request to given url' do
      it 'should return Hash of JSON contents when response is non-error' do
        expect(Net::HTTP).to receive(:get_response).with(uri).and_return(response)
        subject.get_jenkins_info(url)
      end

      it 'should raise Runtime error when response is error' do
        allow(response).to receive(:code).and_return '400'
        expect(Net::HTTP).to receive(:get_response).with(uri).and_return(response)
        expect{
          subject.get_jenkins_info(url)
        }.to raise_error(Exception, /Unable to query .*, please check that it is valid./)
      end
    end
  end

end
