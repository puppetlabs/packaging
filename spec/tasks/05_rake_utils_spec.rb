require 'spec_helper'
load_task '05_rake_utils.rake'

describe RakeUtils do
  describe "#find_task" do
    it "should return a rake task given its name" do
      t = Rake::Task.define_task("foo"){}
      RakeUtils.find_task("foo").should == t
    end
  end
end

