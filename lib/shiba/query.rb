require 'open3'
require 'shiba/explain'
require 'timeout'
require 'thread'

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

    attr_reader :sql, :index


    def fingerprint
      @fingerprint ||= self.class.get_fingerprint(@sql)
    end

    def explain
      Explain.new(@sql, @stats, @backtrace)
    end

    def backtrace
      @backtrace
    end
  end
end
