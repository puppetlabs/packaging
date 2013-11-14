# -*- ruby -*-
require 'spec_helper'
load File.join(SPECDIR,'..', 'lib', 'packaging.rb')
load_task('00_utils.rake')

describe "00_utils" do
  TestVersions = {
    '0.7.0'                       => {
      :git_describe_version       => %w{0.7.0},
      :get_dash_version           => '0.7.0',
      :get_ips_version            => '0.7.0,3.14159-0',
      :get_dot_version            => '0.7.0',
      :get_debversion             => '0.7.0-1puppetlabs1',
      :get_rpmversion             => '0.7.0',
      :get_rpmrelease             => '1',
      :is_rc?                     => false,
      :is_odd?                    => true,
    },
    '0.8.0rc10'                   => {
      :git_describe_version       => %w{0.8.0rc10},
      :get_dash_version           => '0.8.0rc10',
      :get_ips_version            => '0.8.0rc10,3.14159-0',
      :get_dot_version            => '0.8.0rc10',
      :get_debversion             => '0.8.0-0.1rc10puppetlabs1',
      :get_rpmversion             => '0.8.0',
      :get_rpmrelease             => '0.1rc10',
      :is_rc?                     => true,
      :is_odd?                    => false,
    },
    '0.7.0-rc1'                   => {
      :git_describe_version       => %w{0.7.0 rc1},
      :get_dash_version           => '0.7.0-rc1',
      :get_ips_version            => '0.7.0,3.14159-0',
      :get_dot_version            => '0.7.0.rc1',
      :get_debversion             => '0.7.0-0.1rc1puppetlabs1',
      :get_rpmversion             => '0.7.0',
      :get_rpmrelease             => '0.1rc1',
      :is_rc?                     => true,
      :is_odd?                    => true,
    },
    '0.4.0-rc1-63-ge391f55'       => {
      :git_describe_version       => %w{0.4.0 rc1 63},
      :get_dash_version           => '0.4.0-rc1-63',
      :get_ips_version            => '0.4.0,3.14159-63',
      :get_dot_version            => '0.4.0.rc1.63',
      :get_debversion             => '0.4.0-0.1rc1.63puppetlabs1',
      :get_rpmversion             => '0.4.0',
      :get_rpmrelease             => '0.1rc1.63',
      :is_rc?                     => true,
      :is_odd?                    => false,
    },
    '0.6.0-rc1-63-ge391f55-dirty' => {
      :git_describe_version       => %w{0.6.0 rc1 63 dirty},
      :get_dash_version           => '0.6.0-rc1-63-dirty',
      :get_ips_version            => '0.6.0,3.14159-63-dirty',
      :get_dot_version            => '0.6.0.rc1.63.dirty',
      :get_debversion             => '0.6.0-0.1rc1.63dirtypuppetlabs1',
      :get_rpmversion             => '0.6.0',
      :get_rpmrelease             => '0.1rc1.63dirty',
      :is_rc?                     => true,
      :is_odd?                    => false,

    },
    '0.7.0-63-ge391f55'           => {
      :git_describe_version       => %w{0.7.0 63},
      :get_dash_version           => '0.7.0-63',
      :get_ips_version            => '0.7.0,3.14159-63',
      :get_dot_version            => '0.7.0.63',
      :get_debversion             => '0.7.0.63-1puppetlabs1',
      :get_rpmversion             => '0.7.0.63',
      :get_rpmrelease             => '1',
      :is_rc?                     => false,
      :is_odd?                    => true,

    },
    '0.7.0-63-ge391f55-dirty'     => {
      :git_describe_version       => %w{0.7.0 63 dirty},
      :get_dash_version           => '0.7.0-63-dirty',
      :get_ips_version            => '0.7.0,3.14159-63-dirty',
      :get_dot_version            => '0.7.0.63.dirty',
      :get_debversion             => '0.7.0.63.dirty-1puppetlabs1',
      :get_rpmversion             => '0.7.0.63.dirty',
      :get_rpmrelease             => '1',
      :is_rc?                     => false,
      :is_odd?                    => true,
    },
  }

  TestVersions.keys.sort.each do |input|
    before :all do
      Pkg::Config.project_root = File.expand_path(File.dirname(__FILE__))
    end

    describe "Versioning based on #{input}" do
      results = TestVersions[input]
      results.keys.sort_by(&:to_s).each do |method|
        it "using Pkg::Util::Version.#{method} #{input.inspect} becomes #{results[method].inspect}" do
          # We have to call the `stub!` alias because we are trying to stub on
          # `self`, and in the scope of an rspec block that is overridden to
          # return a new double, not to stub a method!
          Pkg::Config.release = "1"

          if method.to_s.include?("deb")
            Pkg::Util::Version.should_receive(:run_git_describe_internal).and_return(input)
            Pkg::Config.packager = "puppetlabs"
          elsif method.to_s.include?("rpm")
            Pkg::Util::Version.should_receive(:run_git_describe_internal).and_return(input)
          else
            Pkg::Util::Version.stub(:uname_r) { "3.14159" }
            Pkg::Util::Version.stub(:is_git_repo) { true }
            Pkg::Util::Version.should_receive(:run_git_describe_internal).and_return(input)
          end
          Pkg::Util::Version.send(method).should == results[method]
        end
      end
    end
  end
end
