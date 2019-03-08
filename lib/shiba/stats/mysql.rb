module Shiba
  module Stats
    class Mysql

      def sql
        <<-EOL
          select * from information_schema.statistics where
          table_schema = DATABASE()
          order by table_name, if(index_name = 'PRIMARY', '', index_name), seq_in_index
        EOL
      end

    end
  end
end