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
      headers = records.shift.map { |header| header.downcase.to_sym }
      records.each do |r|
        h = Hash[headers.zip(r)]
        table = tables[h[:table_name].to_sym] ||= []
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
      primary = schema[table].detect { |index| index[:index_name] == "PRIMARY" }
      primary[:cardinality].to_i
    end

    protected

    def self.read(path)
      # fixes :"expression\n"=>"NULL\n"},
      IO.foreach(path).map { |l| l.gsub!("\n", "").split("\t") }
    end

  end
end