# -*- ruby -*-
require 'spec_helper'
require 'packaging/artifactory'

describe 'artifactory.rb' do
  project = 'puppet-agent'
  project_version = 'ashawithlettersandnumbers'
  default_repo_name = 'testing'
  artifactory_uri = 'https://artifactory.url'

  let(:platform_data) do
    {
      'el-6-x86_64' => {
        artifact: './el/6/PC1/x86_64/puppet-agent-5.3.1.34.gf65f9ef-1.el6.x86_64.rpm',
        repo_config: '../repo_configs/rpm/pl-puppet-agent-f65f9efbb727c3d2d72d6799c0fc345a726f27b5-el-6-x86_64.repo',
        additional_artifacts: [
          './el/6/PC1/x86_64/puppet-agent-extras-5.3.1.34.gf65f9ef-1.el6.x86_64.rpm'
        ],
      },
      'ubuntu-18.04-amd64' => {
        artifact: './deb/bionic/PC1/puppet-agent_5.3.1.34.gf65f9ef-1bionic_amd64.deb',
        repo_config: '../repo_configs/deb/pl-puppet-agent-f65f9efbb727c3d2d72d6799c0fc345a726f27b5-bionic.list',
        additional_artifacts: [
          './deb/bionic/PC1/puppet-agent-extras_5.3.1.34.gf65f9ef-1bionic_amd64.deb'
        ],
      },
      'debian-10-amd64' => {
        artifact: './deb/buster/PC1/puppetdb_5.3.1.34.gf65f9ef-1buster_all.deb',
        repo_config: '../repo_configs/deb/pl-puppetdb-f65f9efbb727c3d2d72d6799c0fc345a726f27b5-buster.list',
        additional_artifacts: [
          './deb/buster/PC1/puppetdb-termini_5.3.1.34.gf65f9ef-1buster_all.deb'
        ],
      },
      'windows-2012-x86' => {
        artifact: './windows/puppet-agent-5.3.1.34-x86.msi',
        repo_config: '',
        additional_artifacts: ['./windows/puppet-agent-extras-5.3.1.34-x86.msi'],
      },
      'windowsfips-2012-x64' => {
        artifact: './windowsfips/puppet-agent-5.3.1.34-x64.msi',
        repo_config: '',
        additional_artifacts: ['./windowsfips/puppet-agent-extras-5.3.1.34-x64.msi'],
      },
      'osx-10.15-x86_64' => {
        artifact: './apple/10.15/PC1/x86_64/puppet-agent-5.3.1.34.gf65f9ef-1.osx10.15.dmg',
        repo_config: '',
        additional_artifacts: [
          './apple/10.15/PC1/x86_64/puppet-agent-extras-5.3.1.34.gf65f9ef-1.osx10.15.dmg'
        ],
      },
      'osx-11-x86_64' => {
        artifact: './apple/11/PC1/x86_64/puppet-agent-5.3.1.34.gf65f9ef-1.osx11.dmg',
        repo_config: '',
        additional_artifacts: [
          './apple/11/PC1/x86_64/puppet-agent-extras-5.3.1.34.gf65f9ef-1.osx11.dmg'
        ],
      },
      'solaris-10-sparc' => {
        artifact: './solaris/10/PC1/puppet-agent-5.3.1.34.gf65f9ef-1.sparc.pkg.gz',
        repo_config: '',
      },
    }
  end

  platform_tags = {
    'el-6-x86_64' => {
      toplevel_repo: 'rpm',
      repo_subdirectories: "#{default_repo_name}/#{project}/#{project_version}/el-6-x86_64",
      package_format: 'rpm',
      package_name: 'path/to/a/el/6/package/puppet-agent-5.3.1.34.gf65f9ef-1.el6.x86_64.rpm',
      all_package_names: [
        'puppet-agent-5.3.1.34.gf65f9ef-1.el6.x86_64.rpm',
        'puppet-agent-extras-5.3.1.34.gf65f9ef-1.el6.x86_64.rpm'
      ]
    },
    'ubuntu-18.04-amd64' => {
      toplevel_repo: 'debian__local',
      repo_subdirectories: "#{default_repo_name}/#{project}/#{project_version}/ubuntu-18.04",
      codename: 'bionic',
      arch: 'amd64',
      package_name: 'path/to/a/bionic/package/puppet-agent_5.3.1.34.gf65f9ef-1bionic_amd64.deb',
      all_package_names: [
        'puppet-agent_5.3.1.34.gf65f9ef-1bionic_amd64.deb',
        'puppet-agent-extras_5.3.1.34.gf65f9ef-1bionic_amd64.deb'
      ]
    },
    'debian-10-amd64' => {
      toplevel_repo: 'debian__local',
      repo_subdirectories: "#{default_repo_name}/#{project}/#{project_version}/debian-10",
      codename: 'buster',
      arch: 'all',
      package_name: 'path/to/a/buster/package/puppetdb_5.3.1.34.gf65f9ef-1buster_all.deb',
      all_package_names: [
        'puppetdb_5.3.1.34.gf65f9ef-1buster_all.deb',
        'puppetdb-termini_5.3.1.34.gf65f9ef-1buster_all.deb'
      ]
    },
    'windows-2012-x86' => {
      toplevel_repo: 'generic',
      repo_subdirectories: "#{default_repo_name}/#{project}/#{project_version}/windows-x86",
      package_name: 'path/to/a/windows/package/puppet-agent-5.3.1.34-x86.msi',
      all_package_names: [
        'puppet-agent-5.3.1.34-x86.msi',
        'puppet-agent-extras-5.3.1.34-x86.msi'
      ]
    },
    'windowsfips-2012-x64' => {
      toplevel_repo: 'generic',
      repo_subdirectories: "#{default_repo_name}/#{project}/#{project_version}/windowsfips-x64",
      package_name: 'path/to/a/windowsfips/package/puppet-agent-5.3.1.34-x64.msi',
      all_package_names: [
        'puppet-agent-5.3.1.34-x64.msi',
        'puppet-agent-extras-5.3.1.34-x64.msi'
      ]
    },
    'osx-10.15-x86_64' => {
      toplevel_repo: 'generic',
      repo_subdirectories: "#{default_repo_name}/#{project}/#{project_version}/osx-10.15-x86_64",
      package_name: 'path/to/an/osx/10.15/package/puppet-agent-5.3.1.34.gf65f9ef-1.osx10.15.dmg',
      all_package_names: [
        'puppet-agent-5.3.1.34.gf65f9ef-1.osx10.15.dmg',
        'puppet-agent-extras-5.3.1.34.gf65f9ef-1.osx10.15.dmg'
      ]
    },
    'osx-11-x86_64' => {
      toplevel_repo: 'generic',
      repo_subdirectories: "#{default_repo_name}/#{project}/#{project_version}/osx-11-x86_64",
      package_name: 'path/to/an/osx/11/package/puppet-agent-5.3.1.34.gf65f9ef-1.osx11.dmg',
      all_package_names: [
        'puppet-agent-5.3.1.34.gf65f9ef-1.osx11.dmg',
        'puppet-agent-extras-5.3.1.34.gf65f9ef-1.osx11.dmg'
      ]
    },
    'solaris-10-sparc' => {
      toplevel_repo: 'generic',
      repo_subdirectories: "#{default_repo_name}/#{project}/#{project_version}/solaris-10-sparc",
      package_name: 'path/to/a/solaris/10/package/puppet-agent-5.3.1.34.gf65f9ef-1.sparc.pkg.gz',
      all_package_names: [
        'puppet-agent-5.3.1.34.gf65f9ef-1.sparc.pkg.gz'
      ]
    },
  }

  let(:artifact) do
    Pkg::ManageArtifactory.new(
      project,
      project_version,
      {
        repo_base: default_repo_name,
        artifactory_uri:  artifactory_uri
      }
    )
  end

  around(:each) do |example|
    original_artifactory_api_key = ENV['ARTIFACTORY_API_KEY']
    ENV['ARTIFACTORY_API_KEY'] = 'anapikeythatdefinitelyworks'
    example.run
    ENV['ARTIFACTORY_API_KEY'] = original_artifactory_api_key
  end

  platform_tags.each do |platform_tag, platform_tag_data|
    describe '#location_for' do
      if platform_tag_data[:codename]
        it 'returns the expected repo name, prepending `pool` for debian-ish platforms' do
          expect(artifact.location_for(platform_tag)).to match_array([
            platform_tag_data[:toplevel_repo],
            platform_tag_data[:repo_subdirectories],
          ])
        end
      else
        it 'returns the expected repo name and paths by default' do
          expect(artifact.location_for(platform_tag)).to match_array([
            platform_tag_data[:toplevel_repo],
            platform_tag_data[:repo_subdirectories],
          ])
        end
      end

      it 'returns the correct paths for the passed in format' do
        expect(artifact.location_for('generic')).to match_array([
          'generic',
          File.join(default_repo_name, project, project_version),
        ])
      end
    end

    describe '#package_name' do
      it 'parses the retrieved yaml file and returns the correct package name' do
        expect(artifact.package_name(platform_data, platform_tag))
          .to eq(File.basename(platform_tag_data[:package_name]))
      end

      it 'fails if it cannot find a valid platform name' do
        new_platform_data = platform_data
        new_platform_data.delete_if { |k| k.match(platform_tag) }
        expect { artifact.package_name(new_platform_data, platform_tag) }
          .to raise_error(RuntimeError, /Package name could not be found from loaded yaml data/)
      end
    end

    describe '#all_package_names' do
      it 'parses the retrieved yaml file and returns the correct package name' do
        all_package_names = artifact.all_package_names(platform_data, platform_tag)
        all_package_names_data = [
          platform_tag_data[:additional_artifacts],
          platform_tag_data[:all_package_names]
        ].flatten.compact
        all_package_names.map! { |p| File.basename(p) }
        all_package_names_data.map! { |p| File.basename(p) }
        expect(all_package_names.size).to eq(all_package_names_data.size)
        expect(all_package_names.sort).to eq(all_package_names_data.sort)
      end

      it 'fails if it cannot find a valid platform name' do
        new_platform_data = platform_data
        new_platform_data.delete_if { |k| k.match(platform_tag) }
        expect { artifact.package_name(new_platform_data, platform_tag) }
          .to raise_error(RuntimeError, /Package name could not be found from loaded yaml data/)
      end
    end

    describe '#deb_list_contents' do
      it "returns the correct contents for the debian list file for #{platform_tag}" do
        if platform_tag_data[:codename]
          platform_repo = platform_tag_data[:toplevel_repo].chomp('/pool')
          codename = platform_tag_data[:codename]
          subdirectories = platform_tag_data[:repo_subdirectories]

          expect(artifact.deb_list_contents(platform_tag))
            .to eq("deb #{artifactory_uri}/#{platform_repo} #{codename} #{subdirectories}")
        else
          expect { artifact.deb_list_contents(platform_tag) }
            .to raise_error(RuntimeError, /is not an apt-based system/)
        end
      end
    end

    describe '#rpm_repo_contents' do
      it "returns the correct contents for the rpm repo file for #{platform_tag}" do
        if platform_tag_data[:package_format] == 'rpm'
          baseurl = 'baseurl=%s/%s/%s' % [
            artifactory_uri,
            platform_tag_data[:toplevel_repo],
            platform_tag_data[:repo_subdirectories]
          ]
          expect(artifact.rpm_repo_contents(platform_tag)).to include(baseurl)
        else
          expect { artifact.rpm_repo_contents(platform_tag) }
            .to raise_error(RuntimeError, /is not a yum-based system/)
        end
      end
    end

    describe '#deploy_properties' do
      it "returns the correct contents for the deploy properties for #{platform_tag}" do
        deploy_properties = artifact.deploy_properties(
          platform_tag,
          File.basename(platform_tag_data[:package_name])
        )
        if platform_tag_data[:codename]
          expect(deploy_properties).to include({
            'deb.distribution' => platform_tag_data[:codename],
            'deb.component' => platform_tag_data[:repo_subdirectories],
            'deb.architecture' => platform_tag_data[:arch]
          })
        else
          expect(deploy_properties).not_to include({
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
      expect { artifact.deploy_package('path/to/el/7/x86_64/package.rpm') }
        .to raise_error(RuntimeError, /Unable to determine credentials for Artifactory/)
      ENV['ARTIFACTORY_API_KEY'] = original_artifactory_api_key
    end
  end
end
