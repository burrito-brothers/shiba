require 'json'
require 'shiba/index'
require 'shiba/explain/check_support'
require 'shiba/explain/checks'
require 'shiba/explain/result'
require 'shiba/explain/mysql_explain'
require 'shiba/explain/postgres_explain'

module Shiba
  class Explain
    include CheckSupport
    extend CheckSupport::ClassMethods
    def initialize(sql, stats, backtrace, options = {})
      @sql = sql
      @backtrace = backtrace

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
        table: get_table,
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

    def get_table
      @sql =~ /\s+from\s*([^\s,]+)/i
      table = $1
      return nil unless table

      table = table.downcase
      table.gsub!('`', '')
      table.gsub!(/.*\.(.*)/, '\1')
      table
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
      when 0..100
        "low"
      when 100..1000
        "medium"
      when 1000..1_000_000_000
        "high"
      end
    end

    def limit
      if @sql =~ /limit\s*(\d+)\s*(offset \d+)?$/i
        $1.to_i
      else
        nil
      end
    end

    def aggregation?
      @sql =~ /select\s*(.*?)from/i
      select_fields = $1
      select_fields =~ /min|max|avg|count|sum|group_concat\s*\(.*?\)/i
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
        @cost = 0
      end
    end

    check :check_no_matching_row_in_const_table
    def check_no_matching_row_in_const_table
      if no_matching_row_in_const_table?
        @result.messages << { tag: "access_type_const" }
        first['key'] = 'PRIMARY'
        @cost = 1
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
        @cost = 0
      end
    end

    # TODO: need to parse SQL here I think
    def simple_table_scan?
      @rows.size == 1 &&  (@sql !~ /order by/i) &&
        (@rows.first['using_index'] || !(@sql =~ /\s+WHERE\s+/i))
    end

    # TODO: we don't catch some cases like SELECT * from foo where index_col = 1 limit 1
    # bcs we really just need to parse the SQL.
    check :check_simple_table_scan
    def check_simple_table_scan
      if simple_table_scan?
        if limit
          @result.messages << { tag: 'limited_scan', cost: limit, table: @rows.first['table'] }
          @cost = limit
        end
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
      if limit
        return_size = limit
      elsif aggregation?
        return_size = 1
      else
        return_size = @result.result_size
      end

      if return_size && return_size > 100
        @result.messages << { tag: "retsize_bad", result_size: return_size }
      else
        @result.messages << { tag: "retsize_good", result_size: return_size }
      end
    end

    def run_checks!
      # first run top-level checks
      _run_checks! do
        :stop if @cost
      end

      if @cost
        # we've decided to stop further analysis at the query level
        @result.cost = @cost
      else
        # run per-table checks
        0.upto(@rows.size - 1) do |i|
          check = Checks.new(@rows, i, @stats, @options, @result)
          check.run_checks!
        end
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
          next [] unless r['possible_keys'] && r['key'].nil?
          possible = r['possible_keys'] - [r['key']]
          possible.map do |p|
            Explain.new(@sql, @stats, @backtrace, force_key: p) rescue nil
          end.compact
        end.flatten
      else
        []
      end
    end
  end
end
