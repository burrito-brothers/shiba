module Shiba
  class Explain
    def initialize(sql, table_sizes)
      @rows = ActiveRecord::Base.connection.select_all("EXPLAIN #{sql}")
      @sizes = table_sizes
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
      "possible: '%{possible_keys}', rows: %{rows}, filtered: %{filtered}, cost: #{self.cost},'%{Extra}'" % first.symbolize_keys
    end

    def to_h
      first.merge(cost: cost)
    end

    def size
      @sizes[first["table"]]
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
        elsif first_extra =~ /Select tables optimized away/
          return 0
        end
      end
      case size
      when :small
        0.1
      when :medium
        0.5
      when :large
        1.0
      when nil
        0.9
      end
    end
  end
end

