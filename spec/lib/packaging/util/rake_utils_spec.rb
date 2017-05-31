require 'spec_helper'

describe "Pkg::Util::RakeUtils" do
  let(:foo_defined?) { Rake::Task.task_defined?(:foo) }
  let(:bar_defined?) { Rake::Task.task_defined?(:bar) }
  let(:define_foo)   { body = proc{}; Rake::Task.define_task(:foo, &body) }
  let(:define_bar)   { body = proc{}; Rake::Task.define_task(:bar, &body) }

  before(:each) do
    if foo_defined?
      Rake::Task[:foo].clear_prerequisites
    end
  end

  describe "#task_defined?" do
    context "given a Rake::Task task name" do
      it "should return true if the task exists" do
        Rake::Task.stub(:task_defined?).with(:foo) {true}
        expect(Pkg::Util::RakeUtils.task_defined?(:foo)).to be_true
      end
      it "should return false if the task does not exist" do
        Rake::Task.stub(:task_defined?).with(:foo) {false}
        expect(Pkg::Util::RakeUtils.task_defined?(:foo)).to be_false
      end
    end
  end

  describe "#get_task" do
    it "should return a task object for a named task" do
      foo = nil
      if !foo_defined?
        foo = define_foo
      else
        foo = Rake::Task[:foo]
      end
      task = Pkg::Util::RakeUtils.get_task(:foo)
      expect(task).to be_a(Rake::Task)
      expect(task).to be(foo)
    end
  end

  describe "#add_dependency" do
    it "should add a dependency to a given rake task" do
      foo = nil
      bar = nil
      if !foo_defined?
        foo = define_foo
      else
        foo = Rake::Task[:foo]
      end
      if !bar_defined?
        bar = define_bar
      else
        bar = Rake::Task[:bar]
      end
      Pkg::Util::RakeUtils.add_dependency(foo, bar)
      expect(Rake::Task["foo"].prerequisites).to include(bar)
    end
  end

  describe "#evaluate_pre_tasks" do
    context "Given a data file with :pre_tasks defined" do
      it "should, for each k=>v pair, add v as a dependency to k" do
        Pkg::Util::Version.stub(:git_describe) { '1.2.3'}
        Pkg::Config.config_from_yaml(File.join(FIXTURES, 'util', 'pre_tasks.yaml'))
        expect(Pkg::Util::RakeUtils).to receive(:add_dependency)
        Pkg::Util::RakeUtils.evaluate_pre_tasks
      end
    end
  end
end
