require 'open3'
require 'shiba/explain'

module Shiba
  class Query
    @@index = 0
    FINGERPRINTER = Shiba.root + "/bin/fingerprint"

    def self.get_fingerprint(query)
      if !@stdin
        @stdin, @stdout, _ = Open3.popen2(FINGERPRINTER)
      end
      @stdin.puts(query.gsub(/\n/, ' '))
      @stdout.readline.chomp
    end

    def initialize(sql, stats)
      @sql = sql
      @stats = stats
      @@index += 1
      @index = @@index
    end

    attr_reader :sql, :index

    def fingerprint
      @fingerprint ||= self.class.get_fingerprint(@sql)
    end

    def explain
      Explain.new(@sql, @stats)
    end
  end
end
