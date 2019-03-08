module Shiba
  module Stats
    class Postgres

      def fetch_indexes
        result = Shiba.connection.query(sql)
        rows = result.to_a.each { |row| normalize(row) }
        rows
      end

      HEADERS = [ "table_name", "index_name", "column_name", "numrows", "is_unique", "is_primary", "numdistinct"]
      # Parses the raw commandline output of running the stats query.
      def parse(raw)
        raw.strip!
        lines       = raw.lines
        header_line = lines.shift
        headers     = header_line.split("|").map(&:strip)

        if headers != HEADERS
          return header_line
        end

        records = []
        lines.each do |line|
          row = line.split("|")
          next if row.size != HEADERS.size

          row.map!(&:strip!)
          records << parse_record(row)
        end

        records.each { |row| normalize(row) }
        records
      end

      def parse_record(row)
        record = Hash[HEADERS.zip(row)]
        record["numrows"]   = record["numrows"].to_i
        record["is_unique"] = cast_bool(record["is_unique"])
        record["numdistinct"] = cast_int(record["numdistinct"])

        record
      end

      def cast_int(value)
        return nil if value == ""
        return value.to_i
      end

      def cast_bool(value)
        case value
        when "t" then true
        when "f" then false
        else
          nil
        end
      end

      def normalize(row)
        # TBD: do better than this, have them return something objecty
        if row['is_primary'] == "t"
          row['index_name'] = "PRIMARY"
          row['non_unique'] = 0
        elsif row['is_unique']
          row['non_unique'] = 0
        end

        if row['numdistinct'].nil?
          # meaning the table's empty.
          row['cardinality'] = 0
        elsif row['numdistinct'] == 0
          # numdistinct is 0 if there's rows in the table but all values are null
          row['cardinality'] = 1
        elsif row['numdistinct'] < 0
          # postgres talks about either cardinality or selectivity (depending.  what's their heuristic?)
          # in the same way we do in the yaml file!
          # if less than zero, it's negative selectivity.
          row['cardinality'] = -(row['numrows'] * row['numdistinct'])
        else
          row['cardinality'] = row['numdistinct']
        end
        row
      end

      def sql
        <<-EOL
          select
            t.relname as table_name,
            i.relname as index_name,
            a.attname as column_name,
            i.reltuples as numrows,
            ix.indisunique as is_unique,
            ix.indisprimary as is_primary,
            s.n_distinct as numdistinct
          from pg_namespace p
          join pg_class t on t.relnamespace = p.oid
          join pg_index ix on ix.indrelid = t.oid
          join pg_class i on i.oid = ix.indexrelid
          join pg_attribute a on a.attrelid = t.oid
          left join pg_stats s on s.tablename = t.relname
            AND s.attname = a.attname
          where
            p.nspname = 'public'
            and a.attnum = ANY(ix.indkey)
            and t.relkind = 'r'
          order by
            t.relname,
            ix.indisprimary desc,
            i.relname,
            array_position(ix.indkey, a.attnum)
        EOL
      end

    end
  end
end