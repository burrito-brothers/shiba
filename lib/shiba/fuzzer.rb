require 'shiba/index_stats'

module Shiba
  class Fuzzer
    def initialize(connection)
      @connection = connection
      @index_stats = IndexStats.new
    end

    attr_reader :connection

    def fuzz!
      fetch_index!
      table_sizes = guess_table_sizes
      @index_stats.tables.each do |name, table|
        table.count = table_sizes[name]
        table.indexes.each do |name, index|
          index.columns.each do |column|
            column.rows_per = index.unique ? 1 : 2
          end
        end
      end
      @index_stats
    end

    private
    STANDARD_FUZZ_SIZE = 5_000

    def fetch_index!
      records = connection.query("select * from information_schema.statistics where table_schema = DATABASE()")
      tables = {}
      records.each do |h|
        h.keys.each { |k| h[k.downcase] = h.delete(k) }
        h["cardinality"] = h["cardinality"].to_i
        @index_stats.add_index_column(h['table_name'], h['index_name'], h['column_name'], h['cardinality'], h['non_unique'] == "0")
      end
    end


    # Create fake table sizes based on the table's index count.
    # The more indexes, the bigger the table. Seems to rank tables fairly well.
    def guess_table_sizes
      index_count_query = "select TABLE_NAME as table_name, count(*) as index_count
        from information_schema.statistics where table_schema = DATABASE()
        and seq_in_index = 1 and index_name not like 'fk_rails%'
        group by table_name order by index_count"

      index_counts = connection.query(index_count_query).to_a

      # 80th table percentile based on number of indexes
      large_table_idx = (index_counts.size * 0.8).round
      large_table = index_counts[large_table_idx]

      sizes = Hash[index_counts.map(&:values)]

      sizes.each do |table_name, index_count|
        if index_count == 0
          index_count = 1
        end

        sizes[table_name] = STANDARD_FUZZ_SIZE * (index_count / large_table['index_count'].to_f)
      end

      sizes
    end
  end
end
