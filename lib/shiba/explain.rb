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
      json = JSON.parse(ex.first['EXPLAIN'])
      @rows = self.class.transform_json(json['query_block'])
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

    def self.transform_table(table)
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
      res
    end

    def self.transform_json(json, res = [])
      rows = []

      if json['ordering_operation']
        return transform_json(json['ordering_operation'])
      elsif json['duplicates_removal']
        return transform_json(json['duplicates_removal'])
      elsif !json['nested_loop'] && !json['table']
        return [{'Extra' => json['message']}]
      elsif json['nested_loop']
        json['nested_loop'].map do |nested|
          transform_json(nested, res)
        end
      elsif json['table']
        res << transform_table(json['table'])
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

    IGNORE_PATTERNS = [
      /No tables used/,
      /Impossible WHERE/,
      /Select tables optimized away/,
      /No matching min\/max row/
    ]

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
      first_extra && IGNORE_PATTERNS.any? { |p| first_extra =~ p }
    end

    def derived?
      first['table'] =~ /<derived.*?>/
    end

    # TODO: need to parse SQL here I think
    def simple_table_scan?
      @rows.size == 1 && first['using_index'] && (@sql !~ /order by/i)
    end

    def limit
      if @sql =~ /limit\s*(\d+)\s*(offset \d+)?$/i
        $1.to_i
      else
        nil
      end
    end

    def tag_query_type
      access_type = first['access_type']

      return unless access_type
      access_type = 'tablescan' if access_type == 'ALL'
      messages << "access_type_" + access_type
    end

    def estimate_row_count
      if no_matching_row_in_const_table?
        messages << "access_type_const"
        first['key'] = 'PRIMARY'
        return 0
      end

      return 0 if ignore_explain?

      messages << "fuzzed_data" if fuzzed?(first_table)

      if simple_table_scan?
        if limit
          messages << 'limited_tablescan'
        else
          messages << 'access_type_tablescan'
        end

        return limit || table_size
      end

      if derived?
        # select count(*) from ( select 1 from foo where blah )
        @rows.shift
        return estimate_row_count
      end

      tag_query_type

      # TODO: if possible_keys but mysql chooses NULL, this could be a test-data issue,
      # pick the best key from the list of possibilities.
      #
      if first_key
        @stats.estimate_key(first_table, first_key, first['used_key_parts'])
      else
        if first['possible_keys'].nil?
          # if no possibile we're table scanning, use PRIMARY to indicate that cost.
          # note that this can be wildly inaccurate bcs of WHERE + LIMIT stuff.
          table_size
        else
          if @options[:force_key]
            # we were asked to force a key, but mysql still told us to fuck ourselves.
            # (no index used)
            #
            # there seems to be cases where mysql lists `possible_key` values
            # that it then cannot use, seen this in OR queries.
            return table_size
          end

          possibilities = [table_size]
          possibilities += first['possible_keys'].map do |key|
            estimate_row_count_with_key(key)
          end
          possibilities.compact.min
        end
      end
    end

    def estimate_row_count_with_key(key)
      Explain.new(@sql, @stats, @backtrace, force_key: key).estimate_row_count
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
      if ignore?
        @cost = 0
        messages << "ignored"
        return
      end

      @cost = estimate_row_count
    end
  end
end

