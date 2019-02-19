require 'strscan'

module Shiba
  class Explain
    class PostgresExplainIndexConditions
      def initialize(string)
        @string = string
        @sc = StringScanner.new(string)
      end

      attr_reader :sc
      def fields
        fields = []
        sc.scan(LPAREN)
        if sc.peek(1) == "("
          while sc.peek(1) == "("
            sc.getch
            fields << extract_field(sc)
            sc.scan(/\s+AND\s+/)
          end
        else
          fields << extract_field(sc)
        end
        fields.uniq
      end

      private
      LPAREN = /\(/
      RPAREN = /\)/

      def parse_value(sc)
        if sc.peek(1) == "'"
          v = ""
          sc.getch
          while true
            if sc.peek(1) == "'"
              if sc.peek(2) == "''"
                sc.scan(/''/)
              else
                sc.getch
                sc.scan(/::\w+(\[\])?/)
                return v
              end
            end
            v += sc.getch
          end
        elsif (v = sc.scan(/\d+\.?\d*/))
          if v.include?('.')
            v.to_f
          else
            v.to_i
          end
        elsif sc.scan(/ANY \(/)
          # parse as string
          v = parse_value(sc)
          sc.scan(/\)/)
          v
        end
      end

      def extract_field(sc)
        # (type = 1)
        # ((type)::text = 1)
        # (((type)::text = ANY ('{User,AnonymousUser}'::text[])) AND ((type)::text = 'User'::text))
        if sc.peek(1) == "("
          # multiple conditions with typed column
          sc.scan(LPAREN)
        end

        if sc.match?(/\S+::/)
          field = sc.scan(/[^\)]+/)
          sc.scan(/\)::\S+/)
        else
          field = sc.scan(/\S+/)
        end

        sc.scan(/\s+\S+\s+/) # operator
        parse_value(sc)

        if sc.scan(RPAREN).nil?
          raise "bad scan; #{sc.inspect}"
        end
        field
      end
    end
  end
end
