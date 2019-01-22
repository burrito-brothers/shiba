module Shiba
  class Explain
    def initialize(sql)
      @rows = ActiveRecord::Base.connection.select_all("EXPLAIN #{sql}")
    end

    def first
      @rows.first.as_json
    end

    def first_key
      first["key"]
    end

    def first_extra
      first["Extra"]
    end

    # shiba: {"possible_keys"=>nil, "key"=>nil, "key_len"=>nil, "ref"=>nil, "rows"=>6, "filtered"=>16.67, "Extra"=>"Using where"}
    def to_log
      "possible: '%{possible_keys}', rows: %{rows}, filtered: %{filtered}, '%{Extra}'" % first.symbolize_keys
    end

    def to_h
      first.merge(cost: cost)
    end

    def cost
      if first_key
        return 0
      elsif first_extra
        if first_extra =~ /no matching row in const table/
          return 0
        elsif first_extra =~ /No tables used/
          return 0
        elsif first_extra =~ /Impossible WHERE/
          return 0
        end
      end
      return 1
    end
  end
end

