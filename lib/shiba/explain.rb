module Shiba
  class Explain
    def initialize(sql, table_sizes)
      @rows = ActiveRecord::Base.connection.select_all("EXPLAIN #{sql}")
      @sizes = table_sizes
      run_checks!
    end

    attr_reader :cost

    def first
      @rows.first.as_json
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
      /Select tables optimized away/
    ]


    COST_FOR_SIZE = {
      :small => 0.1,
      :medium => 0.5,
      :large => 1.0,
      nil => 0.9
    }

    def extra_in_ignore?
      first_extra && IGNORE_PATTERNS.any? { |p| first_extra =~ p }
    end

    def check_missing_key
      return if first_key
      return if extra_in_ignore?

      addl_cost = COST_FOR_SIZE[size]
      if first['possible_keys']
        addl_cost *= 0.5
        msg = "MySQL dedicded to not use these keys for this query: [" + first["possible_keys"] + "].  "
        msg += "Depending on data shape, this may or may not be fine."
        messages << msg
      end
      @cost += addl_cost
    end

    def run_checks!
      @cost = 0
      check_missing_key
    end
  end
end

