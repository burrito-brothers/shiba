require 'shiba/index_stats'

module Shiba
  class Fuzzer

    def initialize(connection)
      @connection = connection
    end

    attr_reader :connection

    def fuzz!
      @index_stats = fetch_index
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

    def fetch_index
      stats = Shiba::IndexStats.new
      records = connection.fetch_indexes
      tables = {}
      records.each do |h|
        h.keys.each { |k| h[k.downcase] = h.delete(k) }
        h["cardinality"] = h["cardinality"].to_i

        stats.add_index_column(h['table_name'], h['index_name'], h['column_name'], h['cardinality'], h['non_unique'] == 0)
      end
      stats
    end

    private

    BIG_FUZZ_SIZE   = 5_000
    SMALL_FUZZ_SIZE = 100


    # Create fake table sizes based on the table's index count.
    # The more indexes, the bigger the table. Seems to rank tables fairly well.
    def guess_table_sizes
      index_counts = connection.count_indexes_by_table
      return if index_counts.empty?

      # 90th table percentile based on number of indexes
      # round down so we don't blow up on small tables
      large_table_idx = (index_counts.size * 0.9).floor
      large_table_index_count = index_counts[large_table_idx]["index_count"].to_f

      sizes = Hash[index_counts.map(&:values)]

      sizes.each do |table_name, index_count|
        if index_count == 0
          index_count = 1
        end

        size = sizes[table_name]
        # Big
        if size >= large_table_index_count
          sizes[table_name] = BIG_FUZZ_SIZE
        else
        #small
          sizes[table_name] = SMALL_FUZZ_SIZE
        end
      end

      sizes
    end
  end
end
