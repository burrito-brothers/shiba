require 'mysql2'

module Shiba
  class Connection
    class Mysql
      def initialize(hash)
        @connection = Mysql2::Client.new(hash)
      end

      def query(sql)
        @connection.query(sql)
      end
    end
  end
end
