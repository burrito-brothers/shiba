require 'pg'

module Shiba
  class Connection
    class Postgres
      def initialize(h)
        @connection = PG.connect( dbname: h['database'], host: h['host'], user: h['username'], password: h['password'], port: h['port'] )
        @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
        query("SET enable_seqscan = OFF")
      end

      def query(sql)
        @connection.query(sql)
      end

      def fetch_indexes
        result = query(<<-EOL
          select
              t.relname as table_name,
              i.relname as index_name,
              a.attname as column_name,
              i.reltuples as numrows,
              ix.indisunique as is_unique,
              ix.indisprimary as is_primary,
              s.stadistinct as numdistinct
          from pg_namespace p
          join pg_class t on t.relnamespace = p.oid
          join pg_index ix on ix.indrelid = t.oid
          join pg_class i on i.oid = ix.indexrelid
          join pg_attribute a on a.attrelid = t.oid
          left join pg_statistic s on s.starelid = t.oid and s.staattnum = a.attnum
          where
              p.nspname = 'public'
              and a.attnum = ANY(ix.indkey)
              and t.relkind = 'r'
          order by
              t.relname,
              ix.indisprimary desc,
              i.relname,
              array_position(ix.indkey, a.attnum)
          EOL
        )
        rows = result.to_a.map do |row|
          # TBD: do better than this, have them return something objecty
          if row['is_primary'] == "t"
            row['index_name'] = "PRIMARY"
            row['non_unique'] = 0
          elsif row['is_unique']
            row['non_unique'] = 0
          end

          if row['numdistinct'].nil?
            # meaning the table's empty.
            row['cardinality'] = 0
          elsif row['numdistinct'] == 0
            # numdistinct is 0 if there's rows in the table but all values are null
            row['cardinality'] = 1
          elsif row['numdistinct'] < 0
            # postgres talks about either cardinality or selectivity (depending.  what's their heuristic?)
            # in the same way we do in the yaml file!
            # if less than zero, it's negative selectivity.
            row['cardinality'] = -(row['numrows'] * row['numdistinct'])
          else
            row['cardinality'] = row['numdistinct']
          end
          row
        end

        #TODO: estimate multi-index column cardinality
        rows
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

