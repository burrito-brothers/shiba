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
      primary['cardinality'].to_i
    end

    def self.estimate_key(table, key, schema)
      table_count = count(table, schema)
      return nil unless table_count

      key_stat = schema[table].detect { |i| i["index_name"] == key }
      return nil unless key_stat

      table_count / key_stat['cardinality']
    end

    protected

    def self.read(path)
      # fixes :"expression\n"=>"NULL\n"},
      IO.foreach(path).map { |l| l.gsub!("\n", "").split("\t") }
    end

  end
end
