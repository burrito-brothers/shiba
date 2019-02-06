require 'yaml'
require 'active_support/core_ext/hash/keys'

module Shiba
  class IndexStats
    def initialize(tables = {})
      @tables = tables
    end

    Table = Struct.new(:name, :count, :indexes) do
      def encode_with(coder)
        coder.map = self.to_h.stringify_keys
        coder.map.delete('name')
        coder.tag = nil
      end

      def build_index(index_name, is_unique)
        indexes[index_name] ||= Index.new(self, index_name, [], is_unique)
      end

      def add_index_column(index_name, column_name, cardinality, is_unique)
        index = build_index(index_name, is_unique)
        index.columns << Column.new(column_name, index, nil, cardinality)

        if is_unique
          # set row count from unique index
          self.count = cardinality
        end
      end
    end

    Index = Struct.new(:table, :name, :columns, :unique) do
      def add_column(column_name, cardinality)
        columns << Column.new(self, column_name, cardinality)
      end

      def encode_with(coder)
        coder.map = self.to_h.stringify_keys
        coder.map.delete('table')
        coder.tag = nil
      end
    end

    Column = Struct.new(:column, :index, :rows_per, :cardinality) do
      def initialize(*args, &block)
        super(*args, &block)

        assign_missing!
      end

      def assign_missing!
        if !self['cardinality'] && index.table.count
          self.cardinality = index.table.count / self['rows_per']
        elsif !self['rows_per'] && index.table.count
          if index.table.count == 0
            val = 1
          else
            val = index.table.count / self['cardinality']
          end
          self.rows_per = val
        end
      end

      def rows_per
        assign_missing!
        super
      end

      def cardinality
        assign_missing!
        super
      end

      def encode_with(coder)
        assign_missing!
        coder.map = self.to_h.stringify_keys
        coder.map.delete('index')
        #coder.map.delete('cardinality')
        coder.tag = nil
      end
    end


    attr_reader :tables

    def table_count(table)
      return @tables[table].count if @tables[table]
    end

    def fetch_index(table, name)
      tbl = @tables[table]
      return nil unless tbl
      tbl.indexes[name]
    end

    def build_table(name)
      @tables[name] ||= Table.new(name, 0, {})
    end

    def add_index_column(table, index_name, column_name, cardinality, is_unique)
      table = build_table(table)
      table.add_index_column(index_name, column_name, cardinality, is_unique)
    end

    def estimate_key(table_name, key, parts)
      index = fetch_index(table_name, key)

      return nil unless index

      index_part = index.columns.detect do |p|
        p.column_name == parts.last
      end

      return nil unless index_part

      index_part.rows_per
    end

    def convert_rows_per_to_output!
      @tables.each do |name, table|
        if table.count.nil?
          #uuuugly.  No unique keys.  we'll take our best guess.
          table.count = table.indexes.map { |i, parts| parts.columns.map { |v| v.cardinality } }.flatten.max
        end
      end

      each_index_column do |table, column|
        cardinality = column.delete('cardinality')

        if table.rows == 0
          column['rows_per'] = 1
          next
        end

        # the bigger the table, the more likely we should be
        # to show percentages for larger counts.
        #
        # small table, show row count up to 10% ish
        # 100_000 - show rows up to 1000, 1%
        # large table, 1_000_000.  show rows up to 0.1% ( 1000 )


        # how many rows does each index value contain?
        if cardinality
          rows_per_item = (table.rows.to_f / cardinality.to_f)
        else
          rows_per_item = column.rows_per
        end

        ratio_per_item = rows_per_item / table.rows.to_f

        if table.rows <= 10
          ratio_threshold = 1_000_0000 # always show a number
        elsif table.rows <= 1000
          ratio_threshold = 0.1
        elsif table.rows <= 1_000_000
          ratio_threshold = 0.01
        elsif table.rows <= 1_000_000_000
          ratio_threshold = 0.001
        end

        if ratio_per_item > ratio_threshold
          column['rows_per'] = (ratio_per_item * 100).round.to_s + "%"
        else
          column['rows_per'] = rows_per_item.round
        end
      end
    end

    def to_yaml
      @tables.to_yaml
    end

    private
    def each_index_column(&block)
      @tables.each do |name, table|
        table.indexes.each do |index_name, index|
          index.columns.each do |column|
            yield(table, column)
          end
        end
      end
    end
  end
end

