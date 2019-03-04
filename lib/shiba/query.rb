require 'open3'
require 'shiba/explain'
require 'timeout'
require 'thread'
require 'digest'

module Shiba
  class Query
    @@index = 0
    FINGERPRINTER = Shiba.root + "/bin/fingerprint"

    @@fingerprinter_mutex = Mutex.new
    def self.get_fingerprint(query)
      @@fingerprinter_mutex.synchronize do
        if !@stdin
          @stdin, @stdout, _ = Open3.popen2(FINGERPRINTER)
        end
        @stdin.puts(query.gsub(/\n/, ' '))
        begin
          Timeout.timeout(2) do
            @stdout.readline.chomp
          end
        rescue StandardError => e
          $stderr.puts("shiba: timed out waiting for fingerprinter on #{query}...")
        end
      end
    end

    def initialize(sql, stats)
      @sql, _, @backtrace = sql.partition(" /*shiba")

      if @backtrace.length > 0
        @backtrace.chomp!("*/")
        @backtrace = JSON.parse(@backtrace)
      else
        @backtrace = []
      end

      @stats = stats
      @@index += 1
      @index = @@index
    end

    attr_reader :sql, :index, :backtrace

    def fingerprint
      @fingerprint ||= self.class.get_fingerprint(@sql)
    end

    def md5
      Digest::MD5.hexdigest(fingerprint)
    end

    def explain
      Explain.new(self, @stats)
    end

    def from_table
      @sql =~ /\s+from\s*([^\s,]+)/i
      table = $1
      return nil unless table

      table = table.downcase
      table.gsub!('`', '')
      table.gsub!(/.*\.(.*)/, '\1')
      table
    end

    def limit
      if @sql =~ /limit\s*(\d+)\s*(offset \d+)?$/i
        $1.to_i
      else
        nil
      end
    end

    def aggregation?
      @sql =~ /select\s*(.*?)from/i
      select_fields = $1
      select_fields =~ /(min|max|avg|count|sum|group_concat)\s*\(.*?\)/i
    end
  end
end
