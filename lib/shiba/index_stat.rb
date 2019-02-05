require 'yaml'
module Shiba
  module IndexStats
    def initialize
      @tables = {}
    end

    def fetch_table(table)
      @tables[table] ||= {}
    end

    def fetch_index(table, name)
      tbl = fetch_table(table)
      tbl['indexes'] ||= {}
      tbl['indexes'][name] || =[]
    end

    def add_index_column(table, index_name, column_name, cardinality, is_unique)
      index = fetch_index(table, index_name)
      index << { 'column' => column_name, 'cardinality' => cardinality }
      if is_unique
        fetch_table(table)['count'] = cardinality
      end
    end

    def convert_cardinality_to_uniqueness!
      @tables.each do |name, value|
        tbl_count = value['count']

        value.each do |idx, parts|
          parts.each do |part|
            cardinality = part.delete('cardinality')
            part['uniqueness'] = (count = 0) ? 1.0 : (cardinality / count).round(2)
          end
        end
      end
    end
  end
end

