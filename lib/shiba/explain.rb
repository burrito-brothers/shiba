require 'json'
require 'shiba/index'
require 'shiba/explain/check_support'
require 'shiba/explain/checks'
require 'shiba/explain/result'
require 'shiba/explain/mysql_explain'
require 'shiba/explain/postgres_explain'

module Shiba
  class Explain
    COST_PER_ROW_READ = 2.5e-07 # TBD; data size would be better
    COST_PER_ROW_SORT = 1.0e-07
    COST_PER_ROW_RETURNED = 3.0e-05

    include CheckSupport
    extend CheckSupport::ClassMethods

    def initialize(query, stats, options = {})
      @query = query
      @sql = query.sql

      @backtrace = query.backtrace

      if options[:force_key]
        @sql = @sql.sub(/(FROM\s*\S+)/i, '\1' + " FORCE INDEX(`#{options[:force_key]}`)")
      end

      @options = options
      @explain_json = Shiba.connection.explain(@sql)

      if Shiba.connection.mysql?
        @rows = Shiba::Explain::MysqlExplain.new.transform_json(@explain_json['query_block'])
      else
        @rows = Shiba::Explain::PostgresExplain.new(@explain_json).transform
      end
      @result = Result.new
      @stats = stats

      run_checks!
    end

    def as_json
      {
        sql: @sql,
        table: @query.from_table,
        md5: @query.md5,
        messages: @result.messages,
        cost: @result.cost,
        severity: severity,
        raw_explain: humanized_explain,
        backtrace: @backtrace
      }
    end

    def messages
      @result.messages
    end

    def cost
      @result.cost
    end

    def first
      @rows.first
    end

    def first_extra
      first["Extra"]
    end

    def no_matching_row_in_const_table?
      first_extra && first_extra =~ /no matching row in const table/
    end

    def severity
      case @result.cost
      when 0..0.01
        "none"
      when 0.01..0.10
        "low"
      when 0.1..1.0
        "medium"
      else
        "high"
      end
    end

    def ignore?
      !!ignore_line_and_backtrace_line
    end

    def ignore_line_and_backtrace_line
      ignore_files = Shiba.config['ignore']
      if ignore_files
        ignore_files.each do |i|
          file, method = i.split('#')
          @backtrace.each do |b|
            next unless b.include?(file)
            next if method && !b.include?(method)
            return [i, b]
          end
        end
      end
      nil
    end

    check :check_query_is_ignored
    def check_query_is_ignored
      if ignore?
        @result.messages << { tag: "ignored" }
        @result.cost = 0
      end
    end

    check :check_no_matching_row_in_const_table
    def check_no_matching_row_in_const_table
      if no_matching_row_in_const_table?
        @result.messages << { tag: "access_type_const", table: @query.from_table }
        first['key'] = 'PRIMARY'
        @result.cost = 0
      end
    end

    IGNORE_PATTERNS = [
      /No tables used/,
      /Impossible WHERE/,
      /Select tables optimized away/,
      /No matching min\/max row/
    ]

    check :check_query_shortcircuits
    def check_query_shortcircuits
      if first_extra && IGNORE_PATTERNS.any? { |p| first_extra =~ p }
        @result.cost = 0
      end
    end

    check :check_fuzzed
    def check_fuzzed
      h = {}
      @rows.each do |row|
        t = row['table']
        if @stats.fuzzed?(t)
          h[t] = @stats.table_count(t)
        end
      end
      if h.any?
        @result.messages << { tag: "fuzzed_data", tables: h }
      end
    end

    def check_return_size
      if @query.limit
        return_size = [@query.limit, @result.result_size].min
      elsif @query.aggregation?
        return_size = 1
      else
        return_size = @result.result_size
      end

      cost = COST_PER_ROW_RETURNED * return_size
      @result.cost += cost
      @result.messages << { tag: "retsize", result_size: return_size, cost: cost }
    end

    def run_checks!
      # first run top-level checks
      _run_checks! do
        :stop if @result.cost
      end

      return if @result.cost

      @result.cost = 0
      # run per-table checks
      0.upto(@rows.size - 1) do |i|
        check = Checks.new(@rows, i, @stats, @options, @query, @result)
        check.run_checks!
      end

      check_return_size
    end

    def humanized_explain
      #h = @explain_json['query_block'].dup
      #%w(select_id cost_info).each { |i| h.delete(i) }
      #h
      @explain_json
    end

    def other_paths
      if Shiba.connection.mysql?
        @rows.map do |r|
          next [] unless r['possible_keys']
          possible = r['possible_keys'] - [r['key']]
          possible.map do |p|
            Explain.new(@query, @stats, force_key: p) rescue nil
          end.compact
        end.flatten
      else
        []
      end
    end
  end
end
