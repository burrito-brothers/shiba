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
  end
end

