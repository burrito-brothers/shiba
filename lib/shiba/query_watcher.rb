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

      fingerprint = Query.get_fingerprint(sql)
      return if @queries[fingerprint]

      lines = Backtrace.from_app
      return if !lines

      @file.puts("#{sql} /*shiba#{lines}*/")
      @queries[fingerprint] = true
    end

  end
end