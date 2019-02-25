require 'mysql2'
require 'json'

module Shiba
  class Connection
    class Mysql
      def initialize(hash)
        @connection = Mysql2::Client.new(hash)
      end

      def query(sql)
        @connection.query(sql)
      end

      def fetch_indexes
        sql =<<-EOL
          select * from information_schema.statistics where
          table_schema = DATABASE()
          order by table_name, if(index_name = 'PRIMARY', '', index_name), seq_in_index
        EOL
        @connection.query(sql)
      end

      def analyze!
        @connection.query("show tables").each do |row|
          t = row.values.first
          @connection.query("analyze table `#{t}`")
        end
      end

      def count_indexes_by_table
        sql =<<-EOL
          select TABLE_NAME as table_name, count(*) as index_count
          from information_schema.statistics where table_schema = DATABASE()
          and seq_in_index = 1 and index_name not like 'fk_rails%'
          group by table_name order by index_count
        EOL

        @connection.query(sql).to_a
      end

      def explain(sql)
        rows = query("EXPLAIN FORMAT=JSON #{sql}").to_a
        JSON.parse(rows.first['EXPLAIN'])
      end

      def mysql?
        true
      end
    end
  end
end
