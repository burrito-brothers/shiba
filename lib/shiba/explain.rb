module Shiba
  class Explain
    def initialize(sql, stats, options = {})
      @sql = sql

      if options[:force_key]
         @sql = @sql.sub(/(FROM\s*\S+)/i, '\1' + " FORCE INDEX(`#{options[:force_key]}`)")
      end

      @options = options
      @rows = Shiba.connection.query("EXPLAIN #{@sql}").to_a
      @stats = stats
      run_checks!
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
      "possible: '%{possible_keys}', rows: %{rows}, filtered: %{filtered}, cost: #{self.cost},'%{Extra}'" % first.symbolize_keys
    end

    def to_h
      first.merge(cost: cost, messages: messages)
    end

    IGNORE_PATTERNS = [
      /no matching row in const table/,
      /No tables used/,
      /Impossible WHERE/,
      /Select tables optimized away/,
      /No matching min\/max row/
    ]

    def table_size
      Shiba::Index.count(first["table"], @stats)
    end

    def ignore_explain?
      first_extra && IGNORE_PATTERNS.any? { |p| first_extra =~ p }
    end

    def derived?
      first['table'] =~ /<derived.*?>/
    end

    # TODO: need to parse SQL here I think
    def no_condition_table_scan?
      @rows.size == 1 && !(@sql =~ /where/i) || @sql =~ /where\s*1=1/i
    end

    def estimate_row_count
      return 0 if ignore_explain?

      if no_condition_table_scan?
        if @sql =~ /limit\s*(\d+)/i
          return $1.to_i
        else
          return table_size
        end
      end

      if derived?
        # select count(*) from ( select 1 from foo where blah )
        @rows.shift
        return estimate_row_count
      end

      # TODO: if possible_keys but mysql chooses NULL, this could be a test-data issue,
      # pick the best key from the list of possibilities.
      #

      if first_key
        Shiba::Index.estimate_key(first_table, first_key, @stats)
      else
        if first['possible_keys'].nil?
          # if no possibile we're table scanning, use PRIMARY to indicate that cost.
          # note that this can be wildly inaccurate bcs of WHERE + LIMIT stuff.
          Shiba::Index.count(first_table, @stats)
        else
          if @options[:force_key]
            # we were asked to force a key, but mysql still told us to fuck ourselves.
            # let's bail out of this case for now and not recurse infinitely
            #
            # unclear whether this is our problem or mysql is giving us bad possible_keys
            return nil
          end

          messages << "possible_key_check"
          possibilities = [Shiba::Index.count(first_table, @stats)]
          possibilities += first['possible_keys'].split(/,/).map do |key|
            estimate_row_count_with_key(key)
          end
          possibilities.compact.min
        end
      end
    end

    def estimate_row_count_with_key(key)
      Explain.new(@sql, @stats, force_key: key).estimate_row_count
    end

    def run_checks!
      @cost = estimate_row_count
    end
  end
end

