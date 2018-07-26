require 'spec_helper'

describe 'Pkg::Metadata' do
  newest_catalog = '0-abcd123'
  test_catalog = '0-xyz6789'
  test_project = 'really_cool_project'
  before(:each) do
    allow_any_instance_of(RelengMetadata::Artifactory).to receive(:most_recent_catalog).and_return(newest_catalog)
  end
  describe '#retrieve_metadata_section' do
    context 'without catalog' do
      it 'retrieves from most recent catalog' do
        expect_any_instance_of(RelengMetadata::Artifactory).to receive(:fetch).with(newest_catalog, 'platforms')
        Pkg::Metadata.retrieve_metadata_section('platforms')
      end
    end
    context 'with catalog' do
      it 'retrieves from given catalog' do
        expect_any_instance_of(RelengMetadata::Artifactory).to receive(:fetch).with(test_catalog, 'platforms')
        Pkg::Metadata.retrieve_metadata_section('platforms', test_catalog)
      end
    end
  end

  describe '#retrieve_project_metadata' do
    context 'without catalog' do
      it 'retrieves from most recent catalog' do
        expect_any_instance_of(RelengMetadata::Artifactory).to receive(:fetch).with(newest_catalog, 'projects', test_project)
        Pkg::Metadata.retrieve_project_metadata(test_project)
      end
    end
    context 'with catalog' do
      it 'retrieves from a given catalog' do
        expect_any_instance_of(RelengMetadata::Artifactory).to receive(:fetch).with(test_catalog, 'projects', test_project)
        Pkg::Metadata.retrieve_project_metadata(test_project, test_catalog)
      end
    end
  end
end
