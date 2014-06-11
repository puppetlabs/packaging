require 'spec_helper'

describe Pkg::Util::OS do
  def as_host_os(platform, &block)
    old = RbConfig::CONFIG['host_os']
    RbConfig::CONFIG['host_os'] = platform
    begin
      yield
    ensure
      RbConfig::CONFIG['host_os'] = old
    end
  end

  it "detects windows when host_os contains mingw" do
    as_host_os('mingw32') do
      expect(Pkg::Util::OS).to be_windows
    end
  end

  it "detects windows when host_os contains mswin60" do
    as_host_os('mswin60') do
      expect(Pkg::Util::OS).to be_windows
    end
  end

  it "does not detect windows when host_os contains darwin" do
    as_host_os('darwin12.5.0') do
      expect(Pkg::Util::OS).to_not be_windows
    end
  end
end
