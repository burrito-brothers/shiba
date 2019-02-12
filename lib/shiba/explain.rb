require 'json'
require 'shiba/index'

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
      @rows = self.class.transform_json(@explain_json['query_block'])
      @stats = stats
      run_checks!
    end

    def as_json
      {
        sql: @sql,
        table: get_table,
        key: first_key,
        tags: messages,
        cost: @cost,
        severity: severity,
        used_key_parts: first['used_key_parts'],
        possible_keys: first['possible_keys'],
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

    def self.transform_table(table, extra = {})
      t = table
      res = {}
      res['table'] = t['table_name']
      res['access_type'] = t['access_type']
      res['key'] = t['key']
      res['used_key_parts'] = t['used_key_parts'] if t['used_key_parts']
      res['rows'] = t['rows_examined_per_scan']
      res['filtered'] = t['filtered']

      if t['possible_keys'] && t['possible_keys'] != [res['key']]
        res['possible_keys'] = t['possible_keys']
      end
      res['using_index'] = t['using_index'] if t['using_index']

      res.merge!(extra)

      res
    end

    def self.transform_json(json, res = [], extra = {})
      rows = []

      if (ordering = json['ordering_operation'])
        index_walk = (ordering['using_filesort'] == false)
        return transform_json(json['ordering_operation'], res, { "index_walk" => index_walk } )
      elsif json['duplicates_removal']
        return transform_json(json['duplicates_removal'], res, extra)
      elsif !json['nested_loop'] && !json['table']
        return [{'Extra' => json['message']}]
      elsif json['nested_loop']
        json['nested_loop'].map do |nested|
          transform_json(nested, res, extra)
        end
      elsif json['table']
        res << transform_table(json['table'], extra)
      end
      res
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
      @rows.size == 1 && first['using_index'] && (@sql !~ /order by/i)
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

    check :check_simple_table_scan
    def check_simple_table_scan
      if simple_table_scan?
        if limit
          messages << 'limited_tablescan'
          @cost = limit
        else
          tag_query_type
          @cost = @stats.estimate_key(first_table, first_key, first['used_key_parts'])
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
      @cost
    end
  end
end
