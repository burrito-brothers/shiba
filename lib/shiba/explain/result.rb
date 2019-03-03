module Shiba
  class Explain
    class Result
      # cost: total rows read
      # result_size: approximate rows returned to the client
      # messages: list of hashes detailing the operations

      def initialize
        @messages = []
        @cost = nil
        @result_size = 0
        @rows_read = 0
      end

      attr_accessor :messages, :cost, :result_size, :rows_read
    end
  end
end

