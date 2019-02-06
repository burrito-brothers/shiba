require 'shiba'
require 'shiba/query'
require 'json'
require 'logger'

module Shiba
  class Analyzer

    def self.analyze(file, output, stats, options)
      new(file, output, stats, options).analyze
    end

    def initialize(file, output, stats, options)
      @file = file
      @output = output
      @stats = stats
      @options = options
      @fingerprints = {}
    end

    def analyze
      idx = 0
      queries = []
      while line = @file.gets
        # strip out colors
        begin
          line.gsub!(/\e\[?.*?[\@-~]/, '')
        rescue ArgumentError => e
          next
        end

        if line =~ /(select.*from.*)/i
          sql = $1
        else
          next
        end

        if @options['limit']
          return if idx == @options['limit']
        end

        if @options['index']
          next unless idx == @options['index']
        end

        sql.chomp!
        query = Shiba::Query.new(sql, @stats)

        if !@fingerprints[query.fingerprint]
          if sql.downcase.start_with?("select")
            if @options['debug']
              require 'byebug'
              debugger
            end

            explain = analyze_query(query)
            if explain
              idx += 1
              queries << explain
            end
          end
        end

        @fingerprints[query.fingerprint] = true
      end
      queries
    end

    protected

    def dump_error(e, query)
      $stderr.puts "got #{e.class.name} exception trying to explain: #{e.message}"
      $stderr.puts "query: #{query.sql} (index #{query.index})"
      $stderr.puts e.backtrace.join("\n")
    end

    def analyze_query(query)
      explain = nil
      begin
        explain = query.explain
      rescue Mysql2::Error => e
        dump_error(e, query) if verbose?
      rescue StandardError => e
        dump_error(e, query)
      end
      return nil unless explain

      json = JSON.dump(explain.as_json)
      write(json)
      explain.as_json
    end

    def write(line)
      @output.puts(line)
    end

    def verbose?
      @options['verbose'] == true
    end
  end
end
