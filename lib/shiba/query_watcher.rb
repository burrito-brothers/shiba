require 'shiba/query'
require 'json'
require 'logger'

module Shiba
  # TO use, put this line in config/initializers: Shiba::QueryWatcher.watch
  module QueryWatcher
    FINGERPRINTS = {}
    IGNORE = /\.rvm|gem|vendor\/|rbenv|seed|db|shiba|test|spec/
    ROOT = Rails.root.to_s

    def self.make_logger(fname)
      Logger.new(fname).tap do |l|
        l.formatter = proc do |severity, datetime, progname, msg|
          "#{msg}\n"
        end
      end
    end

    def self.cleaned_explain(h)
      h.except("id", "select_type", "partitions", "type")
    end

    def self.logger
      @logger ||= make_logger('shiba.log')
    end

    def self.json_logger
      @json_logger ||= make_logger('shiba.log.json')
    end

    def self.watch
      ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        sql = payload[:sql]
        query = Shiba::Query.new(sql)

        if !FINGERPRINTS[query.fingerprint]
          line = app_line
          if sql.start_with?("SELECT") && !line.nil?
            explain = query.explain
            if explain.cost > 0
              json = JSON.dump(sql: sql, explain: cleaned_explain(explain.to_h), line: app_line)
              json_logger.info(json)

              logger.info(sql)
              logger.info(explain.to_log)
              logger.info(app_line)
              logger.info("")
            end
          end

          FINGERPRINTS[query.fingerprint] = true
        end
      end
    end

    def self.app_line
      last_line = caller.detect { |line| line !~ IGNORE }
      if last_line && last_line.start_with?(ROOT)
        last_line = last_line[ROOT.length..-1]
      end

      last_line
    end

  end
end
