require 'yaml'
require 'pp'
require 'shiba/index_stats'

module Shiba
  class Index
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
      stats = IndexStats.new
      tables = {}
      records = read(path)
      headers = records.shift.map { |header| header.downcase }
      records.each do |r|
        h = Hash[headers.zip(r)]
        h["cardinality"] = h["cardinality"].to_i
        stats.add_index_column(h['table_name'], h['index_name'], h['column_name'], h['cardinality'], h['non_unique'] == "0")
      end
      stats
    end

    protected

    def self.read(path)
      # fixes :"expression\n"=>"NULL\n"},
      IO.foreach(path).map { |l| l.gsub!("\n", "").split("\t") }
    end

  end
end
