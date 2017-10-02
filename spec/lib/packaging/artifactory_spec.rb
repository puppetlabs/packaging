# -*- ruby -*-
require 'spec_helper'

describe 'artifactory.rb' do
  describe '#artifactory_authorization' do
    it 'fails if it does not find an api token'
    it 'fails if the user name is not properly set'
    it 'formats the user flag correctly'
  end

  describe '#debian_extras' do
    it 'fails if platform_tag is not valid'
    it 'fails if it cannot set `codename`'
    it 'formats the debian extra curl flags properly'
  end

  describe '#artifactory_curl_command' do
    it 'does the right thing for deb packages'
    it 'does the right thing for deb source packages'
    it 'does the right thing for rpm packages'
    it 'does the right thing for rpm source packages'
    it 'does the right thing for tar archives'
    it 'does the right thing for msis'
    it 'does the right thing for gems'
    it 'fails with an unknown package format'
    it 'formats the curl command properly'
  end
end
