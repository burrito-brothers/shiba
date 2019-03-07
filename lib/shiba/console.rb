require 'shiba'
require 'shiba/activerecord_integration'
require 'shiba/configure'
require 'shiba/analyzer'
require 'shiba/table_stats'
require 'shiba/reviewer'

module Shiba
  # Provides a 'shiba' command to analyze queries from the console.
  # If required in IRB or Pry, the shiba command will automatically be available,
  # as it's injected into those consoles at the bottom of this file.
  #
  # Example:
  # require 'shiba/console'
  #
  # shiba User.all
  # => <shiba results>
  # shiba "select * from users"
  # => <shiba results>
  module Console

    def shiba(query)
      @command ||= Command.new(self)
      @command.execute(query)
    end

    class ExplainRecord

      def initialize(fields)
        @fields = fields
      end

      def comments
        # renderer expects json / key strings
        json = JSON.parse(JSON.dump(@fields))
        renderer.render(json)
      end

      def md5
        @fields[:md5]
      end

      def severity
        @fields[:severity]
      end

      def sql
        @fields[:sql]
      end

      def time
        @fields[:cost]
      end

      def raw_explain
        @fields[:raw_explain]
      end

      def message
        msg = "\n"
        msg << "Severity: #{severity}"
        msg << "----------------------------"
        msg << comments
        msg << "\n"
      end

      def help
        "Available methods: #{self.class.public_instance_methods(false)}"
      end

      def inspect
        "#{to_s}: '#{sql}'. Call the 'help' method on this object for more info."
      end

      protected

      def renderer
        @renderer ||= Review::CommentRenderer.new(tags)
      end

      def tags
        @tags ||= YAML.load_file(Shiba::TEMPLATE_FILE)
      end

    end

    class Command

      def initialize(context)
        @context = context
      end

      def execute(query)
        if !valid_query?(query)
          msg = "Query does not appear to be a valid relation or select sql string"
          msg << "\n#{usage}"
          puts msg
          return
        end

        result = explain(query)
        if result == nil
          puts "Unable to analyze query, please check the SQL syntax for typos."
          return
        end

        record = ExplainRecord.new(result)
        puts record.message
        record
      end

      private

      def usage
        "Examples:
        shiba User.all
        shiba \"select * from users\""
      end

      def valid_query?(query)
        query.respond_to?(:to_sql) ||
          query.respond_to?(:=~) && query =~ /\Aselect/i
      end

      def explain(query)
        query = query.to_sql if query.respond_to?(:to_sql)
        Shiba.configure(connection_options)
        analyzer = Shiba::Analyzer.new(nil, null, stats, { 'sql' => query })
        result = analyzer.analyze.first
      end

      def connection_options
        case
        when defined?(ActiveRecord)
          ActiveRecordIntegration.connection_options
        when File.exist?("config/database.yml")
          Shiba::Configure.activerecord_configuration
        when File.exist?("test/database.yml.example")
          Shiba::Configure.activerecord_configuration("test/database.yml.example")
        else
          raise Shiba::Error.new("ActiveRecord is currently required to analyze queries from the console.")
        end
      end

      def stats
        @stats ||= Shiba::TableStats.new(Shiba.index_config, Shiba.connection, {})
      end

      def null
        @null ||= File.open(File::NULL, "w")
      end

      def puts(message)
        @context.puts(message)
      end

    end

  end
end

if defined?(Pry) || defined?(IRB)
  TOPLEVEL_BINDING.eval('self').extend Shiba::Console
end