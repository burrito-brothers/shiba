require 'shiba'
require 'shiba/query'
require 'json'
require 'logger'

module Shiba
  # TO use, put this line in config/initializers: Shiba::QueryWatcher.watch
  module Cli
    FINGERPRINTS = {}

    def self.make_logger(fname)
      FileUtils.touch fname
      Logger.new(fname).tap do |l|
        l.formatter = proc do |severity, datetime, progname, msg|
          "#{msg}\n"
        end
      end
    end

    def self.cleaned_explain(h)
      h.reject do |k, v|
        ["id", "select_type", "partitions", "type"].include?(k)
      end
    end

    def self.analyze_query(query)
      explain = nil
      begin
        explain = query.explain
      rescue StandardError => e
        puts "got exception trying to explain: #{e}"
      end
      return unless explain

      json = JSON.dump(sql: query.sql, explain: cleaned_explain(explain.to_h), cost: explain.cost)
      puts json
    end

    def self.analyze
      while sql = gets
        sql.chomp!

        query = Shiba::Query.new(sql, {})

        if !FINGERPRINTS[query.fingerprint]
          if sql.downcase.start_with?("select")
            analyze_query(query)
          end
        end

        FINGERPRINTS[query.fingerprint] = true
      end
    end
  end
end

