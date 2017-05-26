# -*- ruby -*-
require 'spec_helper'

describe 'Pkg::Util::Misc' do
  context "#search_and_replace" do
    let(:orig_string) { "#!/bin/bash\necho '__REPO_NAME__'" }
    let(:updated_string) { "#!/bin/bash\necho 'abcdefg'" }
    let(:good_replacements) do
      { __REPO_NAME__: Pkg::Config.repo_name }
    end
    let(:warn_replacements) do
      { __REPO_NAME__: nil }
    end

    it 'replaces the token with the Pkg::Config variable' do
      Pkg::Config.config_from_hash({:project => "foo", :repo_name => 'abcdefg'})
      Pkg::Util::Misc.search_and_replace(orig_string, good_replacements).should eq(updated_string)
    end

    it 'does no replacement if the Pkg::Config variable is not set' do
      Pkg::Config.config_from_hash({:project => 'foo',})
      Pkg::Util::Misc.search_and_replace(orig_string, good_replacements).should eq(orig_string)
    end

    it 'warns and continues if the Pkg::Config variable is unknown to packaging' do
      Pkg::Config.config_from_hash({:project => 'foo',})
      Pkg::Util::Misc.should_receive(:warn).with("replacement value for '#{warn_replacements.keys.first}' probably shouldn't be nil")
      Pkg::Util::Misc.search_and_replace(orig_string, warn_replacements).should eq(orig_string)
    end
  end
end
