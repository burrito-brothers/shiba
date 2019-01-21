module Shiba
  class Query
    def initialize(sql)
      @sql = sql
    end

    PT_FINGERPRINT=File.dirname(__FILE__) + "/pt-fingerprint"
    def fingerprint
      `#{PT_FINGERPRINT} --query="#{@sql}"`
    end
  end
end
