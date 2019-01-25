module Shiba
  class Explain
    def initialize(sql, table_sizes)
      @sql = sql
      @rows = Shiba.connection.query("EXPLAIN #{sql}").to_a
      @sizes = table_sizes
      run_checks!
    end

    attr_reader :cost

    def first
      @rows.first
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

    def size
      @sizes[first["table"]]
    end

    IGNORE_PATTERNS = [
      /no matching row in const table/,
      /No tables used/,
      /Impossible WHERE/,
      /Select tables optimized away/,
      /No matching min\/max row/
    ]


    COST_FOR_SIZE = {
      :small => 0.1,
      :medium => 0.5,
      :large => 1.0,
      nil => 0.9
    }

    def table_size
      10_000
    end

    def extra_in_ignore?
      first_extra && IGNORE_PATTERNS.any? { |p| first_extra =~ p }
    end

    def derived?
      first['table'] =~ /<derived.*?>/
    end

    # TODO: need to parse SQL here I think
    def no_condition_table_scan?
      @rows.size == 1 && !(@sql =~ /where/i) || @sql =~ /where\s*1=1/i
    end

    def check_missing_key
      return if first_key
      return if extra_in_ignore?

      if no_condition_table_scan?
        if @sql =~ /limit\s*(\d+)/i
          limit = $1.to_i
        else
          limit = 1_000_000_000
        end
        rows_scanned = [table_size, limit].min
        # seems like we want to actually garner a row-scan estimate
        return [rows_scanned, 100_000].max / 100_000.0
      end

      if derived?
        @rows.shift
        return check_missing_key
      end

      if first['possible_keys']
        # TODO: for now we're downgrading these to a minor problem.
        #
        # In the future need to transform these into a best of either table-scan
        # or key-check
        msg = "MySQL dedicded to not use these keys for this query: [" + first["possible_keys"] + "].  "
        msg += "Depending on data shape, this may or may not be fine."
        messages << msg
        return
      end

      addl_cost = COST_FOR_SIZE[size]
      @cost += addl_cost
    end

    def run_checks!
      @cost = 0
      check_missing_key
    end
  end
end

