require 'open3'
require 'shiba/explain'

module Shiba
  class Query

    PT_FINGERPRINT=File.dirname(__FILE__) + "/pt-fingerprint"
    @stdin, @stdout = nil
    def self.get_fingerprint(query)
      if !@stdin
        @stdin, @stdout, _, _ = Open3.popen3(PT_FINGERPRINT)
      end
      @stdin.puts(query.gsub(/\n/, ' '))
      @stdout.readline.chomp
    end

    def initialize(sql, table_sizes)
      @sql = sql
      @table_sizes = table_sizes
    end

    def fingerprint
      @fingerprint ||= self.class.get_fingerprint(@sql)
    end

    def explain
      Explain.new(@sql, @table_sizes)
    end
  end
end
