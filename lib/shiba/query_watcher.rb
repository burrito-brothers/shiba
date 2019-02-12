require 'shiba/query'
require 'shiba/backtrace'
require 'json'
require 'rails'

module Shiba
  class QueryWatcher

    def self.watch(file)
      new(file).tap { |w| w.watch }
    end

    attr_reader :queries

    def initialize(file)
      @file = file
      # fixme mem growth on this is kinda nasty
      @queries = {}
    end

    # Logs ActiveRecord SELECT queries that originate from application code.
    def watch
      ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        sql = payload[:sql]

        if sql.start_with?("SELECT")
          fingerprint = Query.get_fingerprint(sql)
          if !@queries[fingerprint]
            if lines = Backtrace.from_app
              @file.puts("#{sql} /*shiba#{lines}*/")
            end
          end
          @queries[fingerprint] = true
        end
      end
    end

  end
end
