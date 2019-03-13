require 'shiba/query'
require 'shiba/backtrace'

module Shiba
  # Logs ActiveRecord SELECT queries that originate from application code.
  class QueryWatcher

    attr_reader :queries

    def initialize(file)
      @file = file
      # fixme mem growth on this is kinda nasty
      @queries = {}
    end

    def call(name, start, finish, id, payload)
      sql = payload[:sql]
      return if !sql.start_with?("SELECT")

      if sql.include?("$1")
        sql = interpolate(sql, payload[:type_casted_binds])
      end

      sql = sql.gsub(/\n/, ' ')

      fingerprint = Query.get_fingerprint(sql)
      lines = Backtrace.from_app

      return unless lines
      return if @queries[fingerprint] && @queries[fingerprint] >= lines.size

      @file.puts("#{sql} /*shiba#{lines}*/")
      @queries[fingerprint] = lines.size
    end

    def interpolate(sql, binds)
      binds.each_with_index do |val, i|
        sql = sql.sub("$#{i +1}", ActiveRecord::Base.connection.quote(val))
      end
      sql
    end
  end
end
