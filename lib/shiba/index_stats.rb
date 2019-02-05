require 'yaml'
require 'shiba/dothash'

module Shiba
  class IndexStats
    def self.from_yaml_file(fname)
      yaml = YAML.load_file(fname)
      IndexStats.new(yaml)
    end

    def initialize(tables = {})
      @tables = tables
    end

    def fetch_table(table)
      @tables[table] ||= DotHash.new
    end

    def fetch_index(table, name)
      tbl = fetch_table(table)
      tbl['indexes'] ||= {}
      tbl['indexes'][name] ||= []
    end

    def estimate_key(table_name, key, parts)
      table = fetch_table(table)
      return nil unless table

      index_arr = tables['indexes'][key]
      return nil unless index_arr

      index_part = index_arr.detect do |p|
        p['column'] == parts.last
      end

      return nil unless index_part

      return 1 if index_part['uniqueness'] == 0.0
      (table['count'].to_f * index_part['uniqueness'].to_f).to_i
    end

    def add_index_column(table, index_name, column_name, cardinality, is_unique)
      index = fetch_index(table, index_name)
      index << { 'column' => column_name, 'cardinality' => cardinality }
      if is_unique
        fetch_table(table)['count'] = cardinality
      end
    end

    def convert_cardinality_to_uniqueness!
      @tables.each do |name, tbl|
        if tbl['count'].nil?
          #uuuugly.  No unique keys.  we'll take our best guess.
          tbl['count'] = tbl['indexes'].map { |i, parts| parts.map { |v| v['cardinality'] } }.flatten.max
        end

        tbl_count = tbl['count']

        tbl['indexes'].each do |idx, parts|
          parts.each do |part|
            cardinality = part.delete('cardinality')
            if tbl_count == 0
              uniqueness = 1.0
            elsif cardinality == 1
              uniqueness = 0.0
            else
              uniqueness = (cardinality.to_f / tbl_count.to_f).round(3)
            end
            part['uniqueness'] = uniqueness
          end
        end

        tbl['count'] = tbl.delete('count')
        tbl['indexes'] = tbl.delete('indexes')
      end
    end

    def to_yaml
      convert_cardinality_to_uniqueness!
      @tables.to_yaml
    end
  end
end

