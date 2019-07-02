require 'shiba/parsers/shiba_string_scanner'

module Shiba
  module Parsers
    # Extracts table name and columns from queries formatted by 'show warnings'.
    class MysqlSelectFields
      def initialize(sql)
        @sql = sql
        @sc = ShibaStringScanner.new(@sql)
      end
      attr_reader :sc

      BACKTICK = "`"

      def tick_match
        sc.match_quoted_double_escape(BACKTICK)
      end

      def parse_fields
        tables = {}

        sc.scan(%r{/\*.*?\*/ select })

        while !sc.scan(/ from/i)
          sc.scan(/distinct /)

          if sc.scan(/\w+\(/)
            parens = 1
            while parens > 0
              case sc.getch
              when '('
                parens += 1
              when ')'
                parens -= 1
              end
            end
            sc.scan(/ AS /)
            tick_match
            # parse function
          elsif sc.scan(/`(.*?)`\.`(.*?)`\.`(.*?)` AS `(.*?)`/)
            db = sc[1]
            table = sc[2]
            col = sc[3]

            tables[table] ||= []
            tables[table] << col

          elsif sc.scan(/`(.*?)`\.`(.*?)` AS `(.*?)`/)
            table = sc[1]
            col = sc[2]

            tables[table] ||= []
            tables[table] << col
          elsif sc.scan(/\(`(.*?)`\.`(.*?)` collate \w+\) AS `(.*?)`/)
            table = sc[1]
            col = sc[2]

            tables[table] ||= []
            tables[table] << col
          elsif sc.scan(/(\d+|NULL|'.*?') AS `(.*?)`/m)
          else
            if ENV['SHIBA_DEBUG']
              raise Shiba::Error.new("unknown stuff: in #{@sql}: #{@sc.rest}")
            end
            return {}
          end

          sc.scan(/,/)
        end

        # resolve table aliases
        if sc.scan(/ `.*?`\.`(.*?)` `(.*?)`/)
          table       = sc[1]
          table_alias = sc[2]

          if tables[table_alias]
            tables[table] = tables[table_alias]
            tables.delete(table_alias)
          end
        end

        tables
      end
    end
  end
end
