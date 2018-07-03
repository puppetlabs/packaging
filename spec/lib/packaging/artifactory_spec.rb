# -*- ruby -*-
require 'spec_helper'
require 'packaging/artifactory'

describe 'artifactory.rb' do

  project = 'puppet-agent'
  project_version = 'ashawithlettersandnumbers'
  default_repo_name = 'testing'
  artifactory_uri = 'https://artifactory.url'
  artifactory_connection = 'https://artifactory.delivery.puppetlabs.net/artifactory/rpm__local'

  let(:platform_data) {
    {
      'el-6-x86_64' => {
        :artifact => "./el/6/PC1/x86_64/puppet-agent-5.3.1.34.gf65f9ef-1.el6.x86_64.rpm",
        :repo_config => "../repo_configs/rpm/pl-puppet-agent-f65f9efbb727c3d2d72d6799c0fc345a726f27b5-el-6-x86_64.repo",
      },
      'ubuntu-16.04-amd64' => {
        :artifact => "./deb/xenial/PC1/puppet-agent_5.3.1.34.gf65f9ef-1xenial_amd64.deb",
        :repo_config => "../repo_configs/deb/pl-puppet-agent-f65f9efbb727c3d2d72d6799c0fc345a726f27b5-xenial.list",
      },
      'windows-2012-x86' => {
        :artifact => "./windows/puppet-agent-5.3.1.34-x86.msi",
        :repo_config => '',
      },
      'eos-4-i386' => {
        :artifact => "./eos/4/PC1/i386/puppet-agent-5.3.1.34.gf65f9ef-1.eos4.i386.swix",
        :repo_config => '',
      },
      'osx-10.12-x86_64' => {
        :artifact => "./apple/10.12/PC1/x86_64/puppet-agent-5.3.1.34.gf65f9ef-1.osx10.12.dmg",
        :repo_config => '',
      },
      'solaris-10-sparc' => {
        :artifact => "./solaris/10/PC1/puppet-agent-5.3.1.34.gf65f9ef-1.sparc.pkg.gz",
        :repo_config => '',
      },
    }
  }

  platform_tags = {
    'el-6-x86_64' => {
      :toplevel_repo => 'rpm',
      :repo_subdirectories => "#{default_repo_name}/#{project}/#{project_version}/el-6-x86_64",
      :package_format => 'rpm',
      :package_name => 'path/to/a/el/6/package/puppet-agent-5.3.1.34.gf65f9ef-1.el6.x86_64.rpm',
    },
    'ubuntu-16.04-amd64' => {
      :toplevel_repo => 'debian__local',
      :repo_subdirectories => "#{default_repo_name}/#{project}/#{project_version}/ubuntu-16.04",
      :codename => 'xenial',
      :arch => 'amd64',
      :package_name => 'path/to/a/xenial/package/puppet-agent_5.3.1.34.gf65f9ef-1xenial_amd64.deb',
    },
    'windows-2012-x86' => {
      :toplevel_repo => 'generic',
      :repo_subdirectories => "#{default_repo_name}/#{project}/#{project_version}/windows-x86",
      :package_name => 'path/to/a/windows/package/puppet-agent-5.3.1.34-x86.msi',
    },
    'eos-4-i386' => {
      :toplevel_repo => 'generic',
      :repo_subdirectories => "#{default_repo_name}/#{project}/#{project_version}/eos-4-i386",
      :package_name => 'path/to/an/eos/4/package/puppet-agent-5.3.1.34.gf65f9ef-1.eos4.i386.swix',
    },
    'osx-10.12-x86_64' => {
      :toplevel_repo => 'generic',
      :repo_subdirectories => "#{default_repo_name}/#{project}/#{project_version}/osx-10.12-x86_64",
      :package_name => 'path/to/an/osx/10.12/package/puppet-agent-5.3.1.34.gf65f9ef-1.osx10.12.dmg',
    },
    'solaris-10-sparc' => {
      :toplevel_repo => 'generic',
      :repo_subdirectories => "#{default_repo_name}/#{project}/#{project_version}/solaris-10-sparc",
      :package_name => 'path/to/a/solaris/10/package/puppet-agent-5.3.1.34.gf65f9ef-1.sparc.pkg.gz',
    },
  }

  let(:artifact) { Pkg::ManageArtifactory.new(project, project_version, {:repo_base => default_repo_name, :artifactory_uri => artifactory_uri})}

  around(:each) do |example|
    original_artifactory_api_key = ENV['ARTIFACTORY_API_KEY']
    ENV['ARTIFACTORY_API_KEY'] = 'anapikeythatdefinitelyworks'
    example.run
    ENV['ARTIFACTORY_API_KEY'] = original_artifactory_api_key
  end

  platform_tags.each do |platform_tag, platform_tag_data|
    describe '#location_for' do
      if platform_tag_data[:codename]
        it 'returns the expected repo name and paths by default, prepending `pool` for debian-ish platforms' do
          expect(artifact.location_for(platform_tag)).to match_array([
            platform_tag_data[:toplevel_repo],
            platform_tag_data[:repo_subdirectories],
            File.join('pool', platform_tag_data[:repo_subdirectories])
          ])
        end
      else
        it 'returns the expected repo name and paths by default' do
          expect(artifact.location_for(platform_tag)).to match_array([
            platform_tag_data[:toplevel_repo],
            platform_tag_data[:repo_subdirectories],
            platform_tag_data[:repo_subdirectories]
          ])
        end
      end

      it 'returns the correct paths for the passed in format' do
        expect(artifact.location_for('generic')).to match_array([
          'generic',
          File.join(default_repo_name, project, project_version),
          File.join(default_repo_name, project, project_version)
        ])
      end
    end

    describe '#package_name' do
      it 'parses the retrieved yaml file and returns the correct package name' do
        expect(artifact.package_name(platform_data, platform_tag)).to eq(File.basename(platform_tag_data[:package_name]))
      end

      it 'fails if it cannot find a valid platform name' do
        new_platform_data = platform_data
        new_platform_data.delete_if { |k| k.match(platform_tag) }
        expect{artifact.package_name(new_platform_data, platform_tag)}.to raise_error
      end
    end

    describe '#deb_list_contents' do
      it "returns the correct contents for the debian list file for #{platform_tag}" do
        if platform_tag_data[:codename]
          expect(artifact.deb_list_contents(platform_tag)).to eq("deb #{artifactory_uri}/#{platform_tag_data[:toplevel_repo].chomp('/pool')} #{platform_tag_data[:codename]} #{platform_tag_data[:repo_subdirectories]}")
        else
          expect{artifact.deb_list_contents(platform_tag)}.to raise_error
        end
      end
    end

    describe '#rpm_repo_contents' do
      it "returns the correct contents for the rpm repo file for #{platform_tag}" do
        if platform_tag_data[:package_format] == 'rpm'
          expect(artifact.rpm_repo_contents(platform_tag)).to include("baseurl=#{artifactory_uri}\/#{platform_tag_data[:toplevel_repo]}\/#{platform_tag_data[:repo_subdirectories]}")
        else
          expect{artifact.rpm_repo_contents(platform_tag)}.to raise_error
        end
      end
    end

    describe '#deploy_properties' do
      it "returns the correct contents for the deploy properties for #{platform_tag}" do
        if platform_tag_data[:codename]
          expect(artifact.deploy_properties(platform_tag)).to include({
            'deb.distribution' => platform_tag_data[:codename],
            'deb.component' => platform_tag_data[:repo_subdirectories]
          })
        else
          expect(artifact.deploy_properties(platform_tag)).not_to include({
            'deb.component' => platform_tag_data[:repo_subdirectories]
          })
        end
      end
    end
  end

  describe '#check_authorization' do
    it 'fails gracefully if authorization is not set' do
      original_artifactory_api_key = ENV['ARTIFACTORY_API_KEY']
      ENV['ARTIFACTORY_API_KEY'] = nil
      expect { artifact.deploy_package('path/to/el/7/x86_64/package.rpm') }.to raise_error
      ENV['ARTIFACTORY_API_KEY'] = original_artifactory_api_key
    end
  end

  describe '#check_promotion' do
  	it 'prints a bunch of shit' do
  		# problems:
  		# can't verify valid tag...not sure where it gets verified or how?
  		#artifact.promote_package('el-6-x86_64', '2018.1')
  		artifact.promote_package('puppet-agent', '1.10.13', '2018.1', 'el-7-x86_64')
  	end
  end

  describe '#test_search_connection' do
  	it 'tries to connect to artifactory and search for a package, given package name' do
  		  # can't connect to artifactory because not real url
  		  #artifact[:artifactory_uri] = "artifactory.delivery.puppetlabs.net/artifactory/rpm__local"
  		  #artifact.test_search_connection('puppet-agent-5.5.1.356.g01a4311-1.el7.x86_64.rpm')
  	end
  end
end
