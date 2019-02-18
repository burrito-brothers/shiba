require 'mysql2'

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
        @connection.query("select * from information_schema.statistics where table_schema = DATABASE()")
      end

      def count_indexes_by_table
        sql = <<-EOL
select TABLE_NAME as table_name, count(*) as index_count
from information_schema.statistics where table_schema = DATABASE()
and seq_in_index = 1 and index_name not like 'fk_rails%'
group by table_name order by index_count
        EOL

        @connection.query(sql).to_a
      end
    end
  end
end
