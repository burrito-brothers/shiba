require 'open3'
require 'shiba/explain'

module Shiba
  class Query

    FINGERPRINTER = Shiba.root + "/bin/fingerprint"
    @stdin, @stdout = nil
    def self.get_fingerprint(query)
      if !@stdin
        @stdin, @stdout, _, _ = Open3.popen3(FINGERPRINTER)
      end
      @stdin.puts(query.gsub(/\n/, ' '))
      @stdout.readline.chomp
    end

    def initialize(sql, stats)
      @sql = sql
      @stats = stats
    end

    attr_reader :sql

    def fingerprint
      @fingerprint ||= self.class.get_fingerprint(@sql)
    end

    def explain
      Explain.new(@sql, @stats)
    end
  end
end
