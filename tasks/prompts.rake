namespace :prompts do
  desc "Test notifications & validations"
  task :test do
    Pkg::Util::Validation.fail_on_branch
    Pkg::Util::Validation.fail_without_tagged_checkout
  end
end
