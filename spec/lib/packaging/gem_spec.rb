require 'spec_helper'

describe 'Pkg::Gem' do
  describe '#shipped_to_rubygems?' do
    before(:each) do
      gem_data = [ {"authors"=>"Puppet Labs",
                    "built_at"=>"2018-12-17T00:00:00.000Z",
                    "created_at"=>"2018-12-18T17:31:50.852Z",
                    "description"=>"Puppet, an automated configuration management tool",
                    "downloads_count"=>32750,
                    "metadata"=>{},
                    "number"=>"6.1.0",
                    "summary"=>"Puppet, an automated configuration management tool",
                    "platform"=>"ruby",
                    "rubygems_version"=>"> 1.3.1",
                    "ruby_version"=>">= 2.3.0",
                    "prerelease"=>false,
                    "licenses"=>[],
                    "requirements"=>[],
                    "sha"=>"71ecec1f554cd7a7f23abf1523e4f0f15fb8ddbc973201234d0cc2a889566373"},
                   {"authors"=>"Puppet Labs",
                    "built_at"=>"2019-01-14T00:00:00.000Z",
                    "created_at"=>"2019-01-15T15:25:25.183Z",
                    "description"=>"Puppet, an automated configuration management tool",
                    "downloads_count"=>540,
                    "metadata"=>{},
                    "number"=>"6.0.5",
                    "summary"=>"Puppet, an automated configuration management tool",
                    "platform"=>"ruby",
                    "rubygems_version"=>"> 1.3.1",
                    "ruby_version"=>">= 2.3.0",
                    "prerelease"=>false,
                    "licenses"=>[],
                    "requirements"=>[],
                    "sha"=>"76811bcf4c5ab75470dd6ae5eea552347767748bd80136cac74261336b208916"},
                    {"authors"=>"Puppet Labs",
                    "built_at"=>"2018-10-31T00:00:00.000Z",
                    "created_at"=>"2018-11-01T17:07:19.274Z",
                    "description"=>"Puppet, an automated configuration management tool",
                    "downloads_count"=>71808,
                    "metadata"=>{},
                    "number"=>"6.0.4",
                    "summary"=>"Puppet, an automated configuration management tool",
                    "platform"=>"ruby",
                    "rubygems_version"=>"> 1.3.1",
                    "ruby_version"=>">= 2.3.0",
                    "prerelease"=>false,
                    "licenses"=>[],
                    "requirements"=>[],
                    "sha"=>"203e8b529d37260115ab7e804e607dde5e543144331b40c3c4a77c2d33445026"},
                   {"authors"=>"Puppet Labs",
                    "built_at"=>"2018-10-31T00:00:00.000Z",
                    "created_at"=>"2018-11-01T17:07:10.268Z",
                    "description"=>"Puppet, an automated configuration management tool",
                    "downloads_count"=>1179,
                    "metadata"=>{},
                    "number"=>"6.0.4",
                    "summary"=>"Puppet, an automated configuration management tool",
                    "platform"=>"x86-mingw32",
                    "rubygems_version"=>"> 1.3.1",
                    "ruby_version"=>">= 2.3.0",
                    "prerelease"=>false,
                    "licenses"=>[],
                    "requirements"=>[],
                    "sha"=>"e57ef7d537aaf66343615d7413d1ff759cc2b6ae95cc90514dd8f3caf0f08cb1"} ]
      allow(JSON).to receive(:parse).and_return(gem_data)
    end
    it 'returns true if gem has already been shipped' do
      expect(Pkg::Gem.shipped_to_rubygems?('puppet', '6.0.5')).to be true
    end
    it 'returns false if gem has not already been shipped' do
      expect(Pkg::Gem.shipped_to_rubygems?('puppet', '6.0.9')).to be false
    end
  end
end
