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

    def self.make_options_parser(options)
      parser = OptionParser.new do |opts|
        opts.on("-h","--host HOST", "sql host") do |h|
          options["host"] = h
        end

        opts.on("-d","--database DATABASE", "sql database") do |d|
          options["database"] = d
        end

        opts.on("-u","--username USER", "sql user") do |u|
          options["username"] = u
        end

        opts.on("-p","--password PASSWORD", "sql password") do |p|
          options["password"] = p
        end

        opts.on("-c","--config FILE", "location of shiba.yml") do |f|
          options["config"] = f
        end

        opts.on("-i","--index INDEX", "location of shiba_index.yml") do |i|
          options["index"] = i.to_i
        end

        opts.on("-l", "--limit NUM", "stop after processing NUM queries") do |l|
          options["limit"] = l.to_i
        end

        opts.on("-s","--stats FILES", "location of index statistics tsv file") do |f|
          options["stats"] = f
        end

        opts.on("-f", "--file FILE", "location of file containing queries") do |f|
          options["file"] = f
        end

        opts.on("-o", "--output FILE", "write to file instead of stdout") do |f|
          options["output"] = f
        end

        opts.on("-t", "--test", "analyze queries at --file instead of analyzing a process") do |f|
          options["test"] = true
        end
      end
    end
  end
end
