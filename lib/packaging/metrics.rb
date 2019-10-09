module Pkg::Metrics
  module_function

  def update_release_metrics
    metrics_repo = 'release-metrics'
    command = <<CMD
git clone git@github.com:puppetlabs/#{metrics_repo}.git
cd #{metrics_repo}
bundle exec add-release --date #{Pkg::Util::Date.today} --project #{Pkg::Config.project} --version #{Pkg::Config.ref}
cd ..
rm -r #{metrics_repo}
CMD
    Pkg::Util::Execution.capture3(command)
  end
end
