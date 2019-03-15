module Shiba
  module Parsers
    class BadParse < StandardError
      def initialize(location, parse_string)
        super("Parse Error @ '#{location}' while parsing '#{parse_string}'")
      end
    end
  end
end
