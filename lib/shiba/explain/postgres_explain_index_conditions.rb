require 'strscan'

module Shiba
  class Explain
    class PostgresExplainIndexConditions
      def initialize(string)
        @string = string
        @sc = StringScanner.new(string)
        @fields = nil
      end

      attr_reader :sc
      def parse!
        return if @fields
        @fields = {}
        sc.scan(LPAREN)
        if sc.peek(1) == "(" && !sc.match?(/\(\w+\)::/)

          while sc.peek(1) == "("
            sc.getch
            extract_field(sc)
            sc.scan(/\s+AND\s+/)
          end
        else
          extract_field(sc)
        end
      end

      def fields
        parse!
        @fields[nil]
      end

      def join_fields
        parse!
        @fields
      end

      private
      LPAREN = /\(/
      RPAREN = /\)/

      def parse_string(sc)
        v = ""
        qchar = sc.getch
        double_quote = qchar * 2
        while true
          if sc.peek(1) == qchar
            if sc.peek(2) == double_quote
              sc.scan(/#{double_quote}/)
            else
              # end of string
              sc.getch
              # optional type hint
              sc.scan(/::\w+(\[\])?/)
              return v
            end
          end
          v += sc.getch
        end
      end

      def parse_value(sc)
        peek = sc.peek(1)
        if peek == "'"
          parse_string(sc)
        elsif peek == '"'
          parse_field(sc)
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
        else
          parse_field(sc)
        end
      end

      def parse_ident(sc)
        peek = sc.peek(1)
        if peek == "("
          sc.getch
          # typed column like (name)::text = 'ben'
          ident = sc.scan(/[^\)]+/)
          sc.scan(/\)::\S+/)
        elsif peek == '"'
          ident = parse_string(sc)
        else
          ident = sc.scan(/[^ \.\)]+/)
        end
        ident
      end

      def parse_field(sc)
        first = nil
        second = nil

        first = parse_ident(sc)
        if sc.scan(/\./)
          second = parse_ident(sc)
          table = first
          field = second
        else
          table = nil
          field = first
        end

        @fields[table] ||= []
        @fields[table] << field unless @fields[table].include?(field)
      end


      def extract_field(sc)
        # (type = 1)
        # ((type)::text = 1)
        # (((type)::text = ANY ('{User,AnonymousUser}'::text[])) AND ((type)::text = 'User'::text))
        table = nil

        parse_field(sc)
        sc.scan(/\s+\S+\s+/) # operator
        parse_value(sc)

        if sc.scan(RPAREN).nil?
          raise "bad scan; #{sc.inspect}"
        end
      end
    end
  end
end
