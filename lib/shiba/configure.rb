require 'pathname'

module Shiba
    module Configure

        # avoiding Rails dependency on the cli tools for now.
        # yanked from https://github.com/rails/rails/blob/v5.0.5/railties/lib/rails/application/configuration.rb
        def self.activerecord_configuration
            yaml = Pathname.new("config/database.yml")

            config = if yaml && yaml.exist?
            require "yaml"
            require "erb"
            YAML.load(ERB.new(yaml.read).result) || {}
            elsif ENV['DATABASE_URL']
            # Value from ENV['DATABASE_URL'] is set to default database connection
            # by Active Record.
            {}
            end

            config
        rescue Psych::SyntaxError => e
            raise "YAML syntax error occurred while parsing #{yaml.to_s}. " \
                "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
                "Error: #{e.message}"
        rescue => e
            raise e, "Cannot load `#{path}`:\n#{e.message}", e.backtrace
        end

    end
end