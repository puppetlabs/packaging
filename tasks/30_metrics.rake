@metrics          = []
@pg_major_version = nil
@db_table         = 'metrics'

def add_metrics args
  @metrics << {
    :bench      => args[:bench],
    :dist       => ( args[:dist]        || ENV['DIST']       ),
    :pkg        => ( args[:pkg]         || @build.project    ),
    :version    => ( args[:version]     || @build.version    ),
    :pe_version => ( args[:pe_version]  || @build.pe_version ),
    :date       => ( args[:date]        || timestamp         ),
    :who        => ( args[:who]         || ENV['USER']       ),
    :where      => ( args[:where]       || hostname          )
  }
end

def post_metrics
  if psql = find_tool('psql')
    ENV["PGCONNECT_TIMEOUT"]="10"

    @metrics.each do |metric|
      date        = metric[:date]
      pkg         = metric[:pkg]
      dist        = metric[:dist]
      bench       = metric[:bench]
      who         = metric[:who]
      where       = metric[:where]
      version     = metric[:version]
      pe_version  = metric[:pe_version]
      @pg_major_version ||= %x{/usr/bin/psql --version}.match(/psql \(PostgreSQL\) (\d)\..*/)[1].to_i
      no_pass_fail = "-w" if @pg_major_version > 8
      %x{#{psql} #{no_pass_fail} -c "INSERT INTO #{@db_table} \
      (date, package, dist, build_time, build_user, build_loc, version, pe_version) \
      VALUES ('#{date}', '#{pkg}', '#{dist}', #{bench}, '#{who}', '#{where}', '#{version}', '#{pe_version}')"}
    end
    @metrics = []
  end
end

def add_shipped_metrics args
  @metrics << {
    :type         => 'shipped',
    :package      => ( args[:package]             || @build.project    ),
    :version      => ( args[:version]             || @build.version    ),
    :pe_version   => ( args[:pe_version]          || @build.pe_version ),
    :is_rc        => ( args[:is_rc]               || false             ),
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

    uri = URI(@build.metrics_url)
    res = Net::HTTP.post_form(
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
