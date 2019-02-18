require 'yaml'
require 'active_support/core_ext/hash/keys'

module Shiba
  class IndexStats

    def initialize(tables = {})
      @tables = tables
      build_from_hash!
    end

    def any?
      @tables.any?
    end

    Table = Struct.new(:name, :count, :indexes) do
      def encode_with(coder)
        coder.map = self.to_h.stringify_keys
        coder.map.delete('name')

        if self.count.nil?
          #uuuugly.  No unique keys.  we'll take our best guess.
          self.count = indexes.map { |i, parts| parts.columns.map { |v| v.raw_cardinality } }.flatten.max
        end

        coder.tag = nil
      end

      def build_index(index_name, is_unique)
        self.indexes[index_name] ||= Index.new(self, index_name, [], is_unique)
      end

      def add_index_column(index_name, column_name, rows_per, cardinality, is_unique)
        index = build_index(index_name, is_unique)
        index.columns << Column.new(column_name, index, rows_per, cardinality)

        if is_unique && !self.count
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
        coder.map.delete('unique') unless unique

        coder.tag = nil
      end
    end

    class Column
      def initialize(column, index, rows_per, cardinality)
        @column = column
        @index = index
        @rows_per = rows_per
        @cardinality = cardinality
      end

      attr_reader :column

      def table_count
        @index.table.count
      end

      def raw_cardinality
        @cardinality
      end

      def rows_per
        return @rows_per if @rows_per && @rows_per.is_a?(Integer)
        return nil if table_count.nil?

        if @rows_per.nil?
          if table_count == 0
            @rows_per = 1
          else
            @rows_per = (table_count / @cardinality).round
          end
        elsif @rows_per.is_a?(String)
          @rows_per = ((@rows_per.to_f / 100.0) * table_count.to_f).round
        end
        @rows_per
      end

      attr_writer :rows_per


      def encode_with(coder)
        coder.map = {'column' => @column}

        count = table_count
        count = 1 if count == 0
        ratio_per_item = self.rows_per / count.to_f

        if count <= 10
          ratio_threshold = 1_000_0000 # always show a number
        elsif count <= 1000
          ratio_threshold = 0.1
        elsif count <= 1_000_000
          ratio_threshold = 0.01
        elsif count <= 1_000_000_000
          ratio_threshold = 0.001
        end

        if ratio_per_item > ratio_threshold
          coder.map['rows_per'] = (ratio_per_item * 100).round.to_s + "%"
        else
          coder.map['rows_per'] = rows_per
        end
        coder.tag = nil
      end
    end

    def build_from_hash!
      @tables = @tables.collect do |tbl_name, tbl_hash|
        t = Table.new(tbl_name, tbl_hash['count'], {})
        tbl_hash['indexes'].each do |idx_name, idx_hash|
          idx_hash['columns'].each do |col_hash|
            t.add_index_column(idx_name, col_hash['column'], col_hash['rows_per'], nil, idx_hash['unique'])
          end
        end
        [tbl_name, t]
      end.to_h
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
      @tables[name] ||= Table.new(name, nil, {})
    end

    def add_index_column(table, index_name, column_name, cardinality, is_unique)
      table = build_table(table)
      table.add_index_column(index_name, column_name, nil, cardinality, is_unique)
    end

    def estimate_key(table_name, key, parts)
      index = fetch_index(table_name, key)

      return nil unless index

      index_part = index.columns.detect do |p|
        p.column == parts.last
      end

      return nil unless index_part

      index_part.rows_per
    end

    def convert_rows_per_to_output!
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
