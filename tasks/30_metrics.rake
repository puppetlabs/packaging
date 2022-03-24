@metrics = []
def add_shipped_metrics(args)
  @metrics << {
    :type         => 'shipped',
    :package      => (args[:package]             || Pkg::Config.project),
    :version      => (args[:version]             || Pkg::Config.version),
    :pe_version   => (args[:pe_version]          || Pkg::Config.pe_version),
    :is_rc        => (args[:is_rc]               || false),
  }
end

def post_shipped_metrics
  require 'net/http'
  @metrics.each do |metric|
    type         = metric[:type]
    package      = metric[:package]
    version      = metric[:version]
    pe_version   = metric[:pe_version]
    is_rc        = metric[:is_rc]

    uri = URI(Pkg::Config.metrics_url)
    Net::HTTP.post_form(
      uri,
      {
        'type'          => type,
        'package'       => package,
        'version'       => version,
        'pe_version'    => pe_version,
        'is_rc'         => is_rc,
      }
    )
  end
end
