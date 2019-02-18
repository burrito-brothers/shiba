module Shiba
  class Connection
    def self.build(hash)
      server_type = hash['server']
      if !server_type
        port = hash['port'].to_i
        if port == 3306
          server_type = 'mysql'
        elsif port == 5432
          server_type = 'postgres'
        else
          raise "couldn't determine server type!  please pass --server"
        end
      end

      if server_type == 'mysql'
        require 'shiba/connection/mysql'
        Shiba::Connection::Mysql.new(hash)
      else
        require 'shiba/connection/postgres'
        Shiba::Connection::Postgres.new(hash)
      end
    end
  end
end
