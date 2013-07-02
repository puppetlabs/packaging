if @build.benchmark
  @metrics          = []
  @pg_major_version = nil
  @db_table         = 'metrics'

  def add_metrics args
    @metrics << {
      :bench        => args[:bench],
      :dist         => ( args[:dist]         || ENV['DIST']       ),
      :package_type => ( args[:package_type] || "Not available"   ),
      :pkg          => ( args[:pkg]          || @build.project    ),
      :version      => ( args[:version]      || @build.version    ),
      :pe_version   => ( args[:pe_version]   || @build.pe_version ),
      :date         => ( args[:date]         || timestamp         ),
      :who          => ( args[:who]          || ENV['USER']       ),
      :where        => ( args[:where]        || hostname          ),
      :success      => ( args[:success]      || false             ),
      :log          => ( args[:log]          || "Not available"   )
    }
  end

  def post_metrics
      metric_server = 'http://localhost:4567/metrics'
      @metrics.each do |metric|
        date         = metric[:date]
        pkg          = metric[:pkg]
        package_type = metric[:package_type]
        dist         = metric[:dist]
        bench        = metric[:bench]
        who          = metric[:who]
        where        = metric[:where]
        version      = metric[:version]
        pe_version   = metric[:pe_version]
        success      = metric[:success]
        log          = metric[:log]

      uri = URI(metric_server)
      begin
        res = Net::HTTP.post_form(
          uri,
          {
            'date'                => Time.now.to_s,
            'package_name'        => pkg,
            'dist'                => dist,
            'package_type'        => package_type,
            'package_build_time'  => bench,
            'build_user'          => who,
            'build_loc'           => where,
            'version'             => version,
            'pe_version'          => pe_version,
            'success'             => success,
            'build_log'           => log,
          })
      rescue Exception => e
        puts e
        puts "Unable to post metrics"
      end
    end
    @metrics = []
  end
end
