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

    protected

    def self.read(path)
      # fixes :"expression\n"=>"NULL\n"},
      IO.foreach(path).map { |l| l.gsub!("\n", "").split("\t") }
    end

  end
end
