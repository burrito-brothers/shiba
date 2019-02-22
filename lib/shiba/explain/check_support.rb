module Shiba
  class Explain
    module CheckSupport
      module ClassMethods
        def check(c)
          @checks ||= []
          @checks << c
        end

        def get_checks
          @checks
        end
      end

      def _run_checks!(&block)
        self.class.get_checks.each do |check|
          res = send(check)
          break if yield == :stop
        end
      end
    end
  end
end

