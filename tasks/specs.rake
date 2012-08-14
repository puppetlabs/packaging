desc "Run all specs"
RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = File.read("spec/spec.opts").chomp || ""
end

