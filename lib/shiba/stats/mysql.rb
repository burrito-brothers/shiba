module Shiba
  module Stats
    class Mysql

      def fetch_indexes
        Shiba.connection.query(sql)
      end

      def sql
        <<-EOL
          select * from information_schema.statistics where
          table_schema = DATABASE()
          order by table_name, if(index_name = 'PRIMARY', '', index_name), seq_in_index
        EOL
      end

      HEADERS = ["table_catalog", "table_schema", "table_name", "non_unique", "index_schema",
         "index_name", "seq_in_index", "column_name","collation", "cardinality", "sub_part",
         "packed", "nullable", "index_type", "comment", "index_comment", "is_visible", "expression"]
      # def\tzammad_test\tactivity_streams\t0\tzammad_test\tPRIMARY\t1\tid\tA\t0\tNULL\tNULL\t\tBTREE\t\t\tYES\tNULL\n
      def parse(raw)
        raw.strip! # avoid whitespace issues
        lines       = raw.lines
        header_line = lines.shift
        headers =     header_line.chomp("\n").split("\t").map(&:downcase)

        if headers != HEADERS
          return false
        end

        records = []
        lines.each do |line|
          row = line.chomp("\n").split("\t")
          if row.size != HEADERS.size
            return false
          end

          row.map!(&:strip)
          records << parse_record(row)
        end

        records
      end

      #
      def parse_record(row)
        record = Hash[HEADERS.zip(row)]

        record["non_unique"]   = record["non_unique"].to_i
        record["seq_in_index"] = record["seq_in_index"].to_i
        record["cardinality"]  = record["cardinality"].to_i
        record["sub_part"]     = cast_null(record["sub_part"])
        record["packed"]       = cast_null(record["packed"])
        record["nullable"]     = cast_bool(record["nullable"])
        record["is_visible"]   = cast_bool(record["is_visible"])
        record["expression"]   = cast_null(record["expression"])

        record
      end

      def cast_null(value)
        value == "NULL" ? nil : value
      end

      def cast_bool(value)
        value == "YES" ? true : false
      end

    end
  end
end