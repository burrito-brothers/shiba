require 'strscan'

module Shiba
  module Parsers
    class ShibaStringScanner < StringScanner
      def match_quoted_double_escape(quote)
        getch

        str = ""
        while ch = getch
          if ch == quote
            if peek(1) == quote
              str += ch
              str += getch
            else
              return str
            end
          else
            str += ch
          end
        end
        str
      end
    end
  end
end

