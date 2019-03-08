module Shiba
  module Stats
    class CLI

      attr_reader :errors

      def initialize
        @user_options = {}
        @errors = []
        parser.parse!
        @options = default_options.merge(@user_options)
      end

      def options
        @options
      end

      def valid?
        return false if @errors.any?

        require_option(:server)
        require_option(:directory)

        if ![ 'mysql', 'postgres' ].include?(options[:server])
          error("--server must be one of 'mysql' or 'postgres', got '#{options[:server]}'")
        end

        # Verbose breaks the printed script
        if options[:script] && options[:verbose]
          error("specify one of --script or --verbose, not both")
        end

        @errors.empty?
      end

      def failure
        return nil if @errors.empty?

        message, help = @errors.first
        message += "\n"
        if help
          message += "\n#{parser}"
        end

        message
      end

      # cd path/to/app
      # echo "select stats sql |"
      # rails dbconsole
      def query_script
        script = ""
        script = "cd #{options[:directory]};\n" if options[:directory]
        script << "echo \"#{stats_sql.strip}\" |\n"
        script << "#{options[:client]}"
        script
      end

      protected

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Query raw table statistics from the database. Supports gathering statistics from production"
          opts.separator ""
          opts.separator "Required:"

          opts.on("-s","--server SERVER", "The database server. Either 'mysql' or 'postgres'") do |s|
            @user_options[:server] = normalize_server(s)
          end

          opts.on("-d", "--directory APP_DIR", "The application directory on the server.") do |d|
            @user_options[:directory] = d
          end

          opts.separator ""
          opts.separator "Options:"

          opts.on("-h","--host HOST", "The host to execute the statistics query from. Defaults to localhost.") do |f|
            @user_options[:host] = f
          end

          opts.on("-e", "--environment ENVIRONMENT", "The database environment. Defaults to 'production'.") do |e|
            @user_options[:environment] = e
          end

          opts.on("--script", "Print a customizable script instead of executing.") do
            @user_options[:script] = true
          end

          opts.on("--client CLIENT", "The client command to run, defaults to 'rails dbconsole'. Can use 'mysql' and 'psql'.") do |c|
            @user_options[:client] = c
          end

          opts.separator ""
          opts.separator "SSH connection options:"

          opts.on("-p", "--proxy PROXY_HOST", "The proxy (jump server) to connect to first.") do |p|
            @user_options[:proxy] = p
          end

          opts.separator ""
          opts.separator "Common options:"

          opts.on("--verbose", "Verbose/debug mode") do
            @user_options[:verbose] = true
          end

          opts.on_tail("--help", "Show this message") do
            puts opts
            exit
          end

          opts.on_tail("--version", "Show version") do
            require 'shiba/version'
            puts Shiba::VERSION
            exit
          end
        end
      end

      def default_options
        env = @user_options[:environment] || 'production'
        { host: "localhost",
          client: "rails dbconsole -p -e #{env}",
          environment: env }
      end

      def stats_sql
        if options[:server] == "mysql"
          require 'shiba/stats/mysql'
          Shiba::Stats::Mysql.new.sql
        else
          require 'shiba/stats/postgres'
          Shiba::Stats::Postgres.new.sql
        end
      end

      def normalize_server(name)
        case name
        when "postgresql" then "postgres"
        when "p"          then "postgres"
        when "m"          then "mysql"
        else
          name
        end
      end

      def require_option(name, description: nil)
        return true if options.key?(name)
        msg = "Required: '#{name}'"
        msg << ". #{description}" if description
        error(msg, help: true)
      end

      def report(message)
        $stderr.puts message if @user_options["verbose"]
      end

      def error(message, help: false)
        @errors << [ message, help ]
      end

    end
  end
end