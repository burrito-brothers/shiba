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
      @queries = []
    end

    def analyze
      idx = 0

      if @options['sql']
        analyze_sql(@options['sql'])
        return @queries
      end

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

        sql.chomp!
        analyze_sql(sql)
      end
      @queries
    end

    def analyze_sql(sql)
      query = Shiba::Query.new(sql, @stats)

      if !@fingerprints[query.fingerprint]
        if sql.downcase.start_with?("select")
          explain = analyze_query(query)
          if explain
            @queries << explain
          end
        end
      end

      @fingerprints[query.fingerprint] = true
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

      if explain.severity != 'none' && explain.other_paths.any?
        paths = [explain] + explain.other_paths
        explain = paths.sort do |a, b|
          if a.cost == b.cost
            case
            when a == explain
              -1
            when b == explain
              1
            else
              0
            end
          else
            a.cost - b.cost
          end
        end.first
      end
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
