if @build.benchmark
  @metrics          = []
  @pg_major_version = nil
  @db_table         = 'metrics'

  def add_metrics args
    @metrics << {
      :date               => ( args[:date]                || timestamp         ),
      :package            => ( args[:package]             || @build.project    ),
      :dist               => ( args[:dist]                || ENV['DIST']       ),
      :package_type       => ( args[:package_type]        || ENV['DIST']       ),
      :package_build_time => ( args[:package_build_time]                       ),
      :version            => ( args[:version]             || @build.version    ),
      :pe_version         => ( args[:pe_version]          || @build.pe_version ),
      :who                => ( args[:who]                 || ENV['USER']       ),
      :where              => ( args[:where]               || hostname          ),
      :success            => ( args[:success]             || true              ),
      :log                => ( args[:log]                 || "Not available"   )
    }
  end

  def post_metrics
      @metrics.each do |metric|
        date               = metric[:date]
        package            = metric[:package]
        dist               = metric[:dist]
        package_type       = metric[:package_type]
        package_build_time = metric[:package_build_time]
        who                = metric[:who]
        where              = metric[:where]
        version            = metric[:version]
        pe_version         = metric[:pe_version]
        success            = metric[:success]
        log                = metric[:log]

      uri = URI(@build.metrics_server)
      res = Net::HTTP.post_form(
        uri,
        {
          'date'                => Time.now.to_s,
          'package_name'        => package,
          'dist'                => dist,
          'package_type'        => package_type,
          'package_build_time'  => package_build_time,
          'build_user'          => who,
          'build_loc'           => where,
          'version'             => version,
          'pe_version'          => pe_version,
          'success'             => success,
          'build_log'           => log,
        })
    end
    @metrics = []
  end
end
