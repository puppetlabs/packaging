# -*- ruby -*-
require 'spec_helper'
require_task '00_utils'

describe "00_utils" do
  TestVersions = {
    '0.7.0'                   => {
      :git_describe_version   => %w{0.7.0},
      :get_dash_version       => '0.7.0',
      :get_ips_version        => '0.7.0,12.2.0-0',
      :get_dot_version        => '0.7.0'
    },
    '0.7.0rc1'                => {
      :git_describe_version   => %w{0.7.0rc1},
      :get_dash_version       => '0.7.0rc1',
      :get_ips_version        => '0.7.0rc1,12.2.0-0',
      :get_dot_version        => '0.7.0rc1'
    },
    '0.7.0-63-ge391f55'       => {
      :git_describe_version   => %w{0.7.0 63},
      :get_dash_version       => '0.7.0-63',
      :get_ips_version        => '0.7.0,12.2.0-63',
      :get_dot_version        => '0.7.0.63'
    },
    '0.7.0-63-ge391f55-dirty' => {
      :git_describe_version   => %w{0.7.0 63 dirty},
      :get_dash_version       => '0.7.0-63-dirty',
      :get_ips_version        => '0.7.0,12.2.0-63-dirty',
      :get_dot_version        => '0.7.0.63.dirty'
    },
  }

  TestVersions.keys.sort.each do |input|
    results = TestVersions[input]
    results.keys.sort_by(&:to_s).each do |method|
      it "using #{method} #{input.inspect} becomes #{results[method].inspect}" do
        self.stub(:uname_r     => "12.2.0")
        self.stub(:is_git_repo => true)
        self.should_receive(:run_git_describe_internal).and_return(input)

        send(method).should == results[method]
      end
    end
  end
end
