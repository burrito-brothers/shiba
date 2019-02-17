require 'json'
require 'shiba/index'
require 'shiba/explain/mysql_explain'

module Shiba
  class Explain
    def initialize(sql, stats, backtrace, options = {})
      @sql = sql
      @backtrace = backtrace

      if options[:force_key]
         @sql = @sql.sub(/(FROM\s*\S+)/i, '\1' + " FORCE INDEX(`#{options[:force_key]}`)")
      end

      @options = options
      ex = Shiba.connection.query("EXPLAIN FORMAT=JSON #{@sql}").to_a
      @explain_json = JSON.parse(ex.first['EXPLAIN'])
      @rows = Shiba::Explain::MysqlExplain.new.transform_json(@explain_json['query_block'])
      @stats = stats
      run_checks!
    end

    def as_json
      {
        sql: @sql,
        table: get_table,
        table_size: table_size,
        key: first_key,
        tags: messages,
        cost: @cost,
        return_size: @return_size,
        severity: severity,
        used_key_parts: first['used_key_parts'],
        possible_keys: first['possible_keys'],
        raw_explain: humanized_explain,
        backtrace: @backtrace
      }
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

    # [{"id"=>1, "select_type"=>"SIMPLE", "table"=>"interwiki", "partitions"=>nil, "type"=>"const", "possible_keys"=>"PRIMARY", "key"=>"PRIMARY", "key_len"=>"34", "ref"=>"const", "rows"=>1, "filtered"=>100.0, "Extra"=>nil}]
    attr_reader :cost

    def first
      @rows.first
    end

    def first_table
      first["table"]
    end

    def first_key
      first["key"]
    end

    def first_extra
      first["Extra"]
    end

    def messages
      @messages ||= []
    end

    # shiba: {"possible_keys"=>nil, "key"=>nil, "key_len"=>nil, "ref"=>nil, "rows"=>6, "filtered"=>16.67, "Extra"=>"Using where"}
    def to_log
      plan = first.symbolize_keys
      "possible: #{plan[:possible_keys]}, rows: #{plan[:rows]}, filtered: #{plan[:filtered]}, cost: #{self.cost}, access: #{plan[:access_type]}"
    end

    def to_h
      first.merge(cost: cost, messages: messages)
    end

    def table_size
      @stats.table_count(first['table'])
    end

    def fuzzed?(table)
      @stats.fuzzed?(first['table'])
    end

    def no_matching_row_in_const_table?
      first_extra && first_extra =~ /no matching row in const table/
    end

    def ignore_explain?
    end

    def derived?
      first['table'] =~ /<derived.*?>/
    end

    # TODO: need to parse SQL here I think
    def simple_table_scan?
      @rows.size == 1 &&  (@sql !~ /order by/i) &&
        (first['using_index'] || !(@sql =~ /\s+WHERE\s+/i))
    end

    def severity
      case @cost
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

    def self.check(c)
      @checks ||= []
      @checks << c
    end

    def self.get_checks
      @checks
    end

    check :check_query_is_ignored
    def check_query_is_ignored
      if ignore?
        messages << "ignored"
        @cost = 0
      end
    end

    check :check_no_matching_row_in_const_table
    def check_no_matching_row_in_const_table
      if no_matching_row_in_const_table?
        messages << "access_type_const"
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

    check :check_fuzzed
    def check_fuzzed
      messages << "fuzzed_data" if fuzzed?(first_table)
    end

    # TODO: we don't catch some cases like SELECT * from foo where index_col = 1 limit 1
    # bcs we really just need to parse the SQL.
    check :check_simple_table_scan
    def check_simple_table_scan
      if simple_table_scan?
        if limit
          messages << 'limited_scan'
          @cost = limit
        end
      end
    end

    check :check_derived
    def check_derived
      if derived?
        # select count(*) from ( select 1 from foo where blah )
        @rows.shift
        return run_checks!
      end
    end


    check :tag_query_type
    def tag_query_type
      access_type = first['access_type']

      if access_type.nil?
        @cost = 0
        return
      end

      access_type = 'tablescan' if access_type == 'ALL'
      messages << "access_type_" + access_type
    end

    #check :check_index_walk
    # disabling this one for now, it's not quite good enough and has a high
    # false-negative rate.
    def check_index_walk
      if first['index_walk']
        @cost = limit
        messages << 'index_walk'
      end
    end

    check :check_key_size
    def check_key_size
      # TODO: if possible_keys but mysql chooses NULL, this could be a test-data issue,
      # pick the best key from the list of possibilities.
      #
      if first_key
        @cost = @stats.estimate_key(first_table, first_key, first['used_key_parts'])
      else
        if first['possible_keys'].nil?
          # if no possibile we're table scanning, use PRIMARY to indicate that cost.
          # note that this can be wildly inaccurate bcs of WHERE + LIMIT stuff.
          @cost = table_size
        else
          if @options[:force_key]
            # we were asked to force a key, but mysql still told us to fuck ourselves.
            # (no index used)
            #
            # there seems to be cases where mysql lists `possible_key` values
            # that it then cannot use, seen this in OR queries.
            @cost = table_size
          else
            possibilities = [table_size]
            possibilities += first['possible_keys'].map do |key|
              estimate_row_count_with_key(key)
            end
            @cost = possibilities.compact.min
          end
        end
      end
    end

    def check_return_size
      if limit
        @return_size = limit
      elsif aggregation?
        @return_size = 1
      else
        @return_size = @cost
      end

      if @return_size && @return_size > 100
        messages << "retsize_bad"
      else
        messages << "retsize_good"
      end
    end

    def estimate_row_count_with_key(key)
      explain = Explain.new(@sql, @stats, @backtrace, force_key: key)
      explain.run_checks!
    rescue Mysql2::Error => e
      if /Key .+? doesn't exist in table/ =~ e.message
        return nil
      end

      raise e
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

    def run_checks!
      self.class.get_checks.each do |check|
        res = send(check)
        break if @cost
      end
      check_return_size
      @cost
    end

    def humanized_explain
      h = @explain_json['query_block'].dup
      %w(select_id cost_info).each { |i| h.delete(i) }
      h
    end
  end
end
