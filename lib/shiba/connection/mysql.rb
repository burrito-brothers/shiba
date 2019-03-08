require 'mysql2'
require 'json'
require 'shiba/parsers/mysql_select_fields'

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

      def tables
        @connection.query("show tables").map { |r| r.values.first }
      end

      def each_column_size
        tables.each do |t|
          sql = <<-EOL
            select * from information_schema.columns where table_schema = DATABASE()
            and table_name = '#{t}'
          EOL
          columns = @connection.query(sql)
          col_hash = Hash[columns.map { |c| [c['COLUMN_NAME'], c] }]
          estimate_column_sizes(t, col_hash)

          col_hash.each do |c, h|
            yield(t, c, h['size'])
          end
        end
      end

      def estimate_column_sizes(table, hash)
        columns_to_sample = []
        hash.each do |name, row|
          row['size'] = case row['DATA_TYPE']
          when 'tinyint', 'year', 'enum', 'bit'
            1
          when 'smallint'
            2
          when 'mediumint', 'date', 'time'
            3
          when 'int', 'decimal', 'float', 'timestamp'
            4
          when 'bigint', 'datetime', 'double'
            8
          else
            columns_to_sample << name
            nil
          end
        end

        return unless columns_to_sample.any?

        select_fields = columns_to_sample.map do |c|
          "AVG(LENGTH(`#{c}`)) as `#{c}`"
        end.join(', ')

        res = @connection.query("select #{select_fields}, count(*) as cnt from ( select * from `#{table}` limit 10000 ) as v").first
        if res['cnt'] == 0
          # muggles, no data. impossible to know actual size of blobs/varchars, safer to err on side of 0
          res.keys.each do |c|
            hash[c] && hash[c]['size'] = 0
          end
        else
          res.each do |k, v|
            hash[k] && hash[k]['size'] = v.to_i
          end
        end

        hash
      end

      def analyze!
        tables.each do |t|
          @connection.query("analyze table `#{t}`") rescue nil
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
        explain = JSON.parse(rows.first['EXPLAIN'])
        warnings = query("show warnings").to_a
        [explain, parse_select_fields(warnings)]
      end

      def parse_select_fields(warnings)
        normalized_sql = warnings.detect { |w| w["Code"] == 1003 }["Message"]

        Parsers::MysqlSelectFields.new(normalized_sql).parse_fields
      end

      def mysql?
        true
      end
    end
  end
end
