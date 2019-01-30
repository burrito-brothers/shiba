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

    def self.dump_error(e, query)
      $stderr.puts "got exception trying to explain: #{e.message}"
      $stderr.puts "query: #{query.sql} (index #{query.index})"
      $stderr.puts e.backtrace.join("\n")
    end

    def self.analyze_query(query)
      explain = nil
      begin
        explain = query.explain
      rescue Mysql2::Error => e
        # we're picking up crap on the command-line that's not good SQL.  ignore it.
        if !(e.message =~ /You have an error in your SQL syntax/)
          dump_error(e, query)
        end
      rescue StandardError => e
        dump_error(e, query)
      end
      return false unless explain

      json = JSON.dump(sql: query.sql, idx: query.index, explain: cleaned_explain(explain.to_h), cost: explain.cost)
      puts json
      true
    end

    def self.analyze(file, stats, options = {})
      file = $stdin if file.nil?
      idx = 0
      while line = file.gets
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

        if options['index']
          next unless idx == options['index']
        end

        sql.chomp!

        query = Shiba::Query.new(sql, stats)

        if !FINGERPRINTS[query.fingerprint]
          if sql.downcase.start_with?("select")
            if options['debug']
              require 'byebug'
              debugger
            end

            if analyze_query(query)
              idx += 1
            end
          end
        end

        FINGERPRINTS[query.fingerprint] = true
      end
    end
  end
end

