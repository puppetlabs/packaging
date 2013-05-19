require 'spec_helper'
load_task '00_monkey_patches.rake'

describe Rake::Task do
  describe "@count" do
    it "should have a read and write accessors for @count" do
      t = Rake::Task.define_task("foo"){}
        t.should respond_to(:count)
        t.should respond_to(:count=)
    end
  end

  describe "#unshift" do
    it "should insert a block before an existing execution block" do
      t = Rake::Task.define_task("foo"){ puts "foo" }
      t.unshift{ puts "bar" }
      # first
      self.should_receive(:puts).with("bar")
      # second
      self.should_receive(:puts).with("foo")
      t.execute
    end
  end
end


