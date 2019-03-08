require 'pg'
require 'shiba/stats/postgres'

module Shiba
  class Connection
    class Postgres
      def initialize(h)
        @connection = PG.connect( dbname: h['database'], host: h['host'], user: h['username'], password: h['password'], port: h['port'] )
        @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
        query("SET enable_seqscan = OFF")
        query("SET random_page_cost = 0.01")
      end

      def query(sql)
        @connection.query(sql)
      end

      def fetch_indexes
        stats = Stats::Postgres.new
        stats.fetch_indexes
      end

      def count_indexes_by_table
        sql = <<-EOL
          select tablename as table_name, count(*) as index_count from pg_indexes where schemaname='public' group by 1 order by 2
        EOL
        @connection.query(sql).to_a
      end

      def explain(sql)
        rows = query("EXPLAIN (FORMAT JSON) #{sql}").to_a
        rows.first["QUERY PLAN"]
      end

      def mysql?
        false
      end
    end
  end
end
