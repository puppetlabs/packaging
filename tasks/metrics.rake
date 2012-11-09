if @benchmark
  module Metrics_helper
    @metrics          = []
    @pg_major_version = nil
    @db_table         = 'metrics'

    def self.add args
      @metrics << {
        :dist       => args[:dist],
        :bench      => args[:bench],
        :date       => args[:date]        || timestamp,
        :pkg        => args[:pkg]         || @name,
        :who        => args[:who]         || ENV['USER'],
        :where      => args[:where]       || hostname,
        :version    => args[:version]     || @version,
        :pe_version => args[:pe_version]  || @pe_version
      }
    end

    def self.post
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
        %x{/usr/bin/psql #{no_pass_fail} -c "INSERT INTO #{@db_table} \
        (date, package, dist, build_time, build_user, build_loc, version, pe_version) \
        VALUES ('#{date}', '#{pkg}', '#{dist}', #{bench}, '#{who}', '#{where}', '#{version}', '#{pe_version}')"}
      end
      @metrics = []
    end
  end
end
