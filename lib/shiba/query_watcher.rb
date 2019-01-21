module Shiba
  # TO use, put this line in config/initializers: Shiba::QueryWatcher.watch
  module QueryWatcher
    STATEMENTS = {}
    IGNORE = /\.rvm|gem|vendor\/|slow_query_logger|rbenv|test|spec|seed|db/
    ROOT = Rails.root.to_s
          
    def self.watch
      ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        line = app_line
        if !STATEMENTS.key?(line)
          sql = payload[:sql]
        
          if sql.start_with?("SELECT")
            r = ActiveRecord::Base.connection.execute("EXPLAIN #{sql}")
            index = r.to_a.last[5]
            if !index
              explain = r.to_a.flatten.join("|")
              if !explain.end_with?("no matching row in const table")
                Rails.logger.info("shiba: #{sql} #{explain}")
              end
            end
          end  

          STATEMENTS[line] = true
        end    
      end
    end
        
    def self.app_line
      last_line = caller.detect { |line| line !~ IGNORE }
      if last_line && last_line.start_with?(ROOT)
        last_line = last_line[ROOT.length..-1]
      end
      
      last_line
    end
        
  end
end