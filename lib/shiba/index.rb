module Shiba
  module Index

    # Given the path to the information_schema.statistics output, returns index statistics keyed by table name.
    # Examples:
    # Exploring the schema:
    #
    # schema_stats = Index.parse("./shiba/schema_stats.tsv")
    # schema_stats.keys
    # => :users, :posts, :comments
    # schema_stats[:users]
    # => {:table_schema=>"blog_test", :table_name=>"users", :non_unique=>"0", :column_name=>"id", :cardinality=>"2", :is_visible=>"YES", :"expression\n"=>"NULL\n"}
    #
    def self.parse(path)
      tables = {}
      records = read(path)
      headers = records.shift.map { |header| header.downcase }
      records.each do |r|
        h = Hash[headers.zip(r)]
        h["cardinality"] = h["cardinality"].to_i
        table = tables[h['table_name']] ||= []
        table.push(h)
      end
      tables
    end

    # Getting a row count for a table:
    #
    # schema_stats = Index.parse("./shiba/schema_stats.tsv")
    # users_count = Index.count(:users, schema_stats)
    # => 2
    def self.count(table, schema)
      return nil unless schema[table]
      primary = schema[table].detect { |index| index['index_name'] == "PRIMARY" }
      if primary.nil?
        # find the highest cardinality of a unique index, if it exists
        schema[table].map do |index|
          if index['non_unique'].to_i == 0
            index['cardinality']
          else
            nil
          end
        end.compact.max
      else
        primary['cardinality'].to_i
      end
    end

    def self.fuzzed?(table, schema)
      return nil unless schema[table]
      schema[table].first['fuzzed']
    end

    def self.estimate_key(table, key, parts, schema)
      table_count = count(table, schema)
      return nil unless table_count

      key_stat = schema[table].detect do |i|
        i["index_name"] == key && i["column_name"] == parts.last
      end

      return nil unless key_stat

      return 0 if key_stat['cardinality'] == 0
      table_count / key_stat['cardinality']
    end

    def self.query(connection)
      records = connection.query("select * from information_schema.statistics where table_schema = DATABASE()")
      tables = {}
      records.each do |h|
        h.keys.each { |k| h[k.downcase] = h.delete(k) }
        h["cardinality"] = h["cardinality"].to_i
        table = tables[h['table_name']] ||= []
        table.push(h)
      end
      tables
    end

    FUZZ_SIZE = 6_001

    # Up the cardinality on our indexes.
    # Non uniques have a little less cardinality.
    def self.fuzz!(stats)
      stats.each do |_,indexes|
        indexes.each do |idx|
          idx['cardinality'] = FUZZ_SIZE

          if idx['non_unique'] == 1
            idx['cardinality'] = (idx['cardinality'] * 0.7).round
          end

          idx['fuzzed'] = true
        end
      end
    end

    MINIMUM_TABLE_SIZE = 500

    # Approximate median size of the tables is less than 500.
    def self.insufficient_stats?(stats)
      if stats.length == 0
        return true
      end

      # Calculate a rough median.
      primary_keys = stats.map do |_,indexes|
        indexes.detect { |idx| idx['index_name'] == 'PRIMARY' } || {}
      end

      table_counts = primary_keys.map { |pk| pk['cardinality'].to_i }
      median = table_counts[table_counts.size/2]

      return median < MINIMUM_TABLE_SIZE
    end

    protected

    def self.read(path)
      # fixes :"expression\n"=>"NULL\n"},
      IO.foreach(path).map { |l| l.gsub!("\n", "").split("\t") }
    end

  end
end
