require 'pathname'
require 'pp'
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

    def self.read_config_file(option_file, default)
      file_to_read = nil
      if option_file
        if !File.exist?(option_file)
          $stderr.puts "no such file: #{option_file}"
          exit 1
        end
        file_to_read = option_file
      elsif File.exist?(default)
        file_to_read = default
      end

      if file_to_read
        YAML.load_file(file_to_read)
      else
        {}
      end
    end

    def self.main_config
      @config ||= {}
    end

    def self.configure_main_yaml(yaml)
      @config = read_config_file(yaml, "config/shiba.yml")
    end

    def self.configure_index_yaml(yaml)
      @indexes = read_config_file(yaml, "config/shiba_index.yml")
    end
  end
end
