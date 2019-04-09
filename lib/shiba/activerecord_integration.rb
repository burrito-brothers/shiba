require 'shiba/query_watcher'
require 'active_support/notifications'
require 'active_support/lazy_load_hooks'
require 'shiba/configure'

module Shiba
  # Integrates ActiveRecord with the Query Watcher by setting up the query log path, and the
  # connection options for the explain command, which it runs when the process exits.
  #
  # SHIBA_DIR, SHIBA_QUERY_LOG_NAME and SHIBA_DEBUG=true environment variables may be set.
  class ActiveRecordIntegration

    attr_reader :path, :watcher

    def self.install!
      return false if @installed
      if defined?(Rails.env) && Rails.env.production?
        Rails.logger.error("Shiba watcher is not intended to run in production, stopping install.")
        return false
      end

      ActiveSupport.on_load(:active_record) do
        Shiba::ActiveRecordIntegration.start_watcher
      end

      @installed = true
    end

    def self.connection_options
        cx = ActiveRecord::Base.connection.raw_connection
        if cx.respond_to?(:query_options)
          # mysql
          c = cx.query_options.merge(server: 'mysql')
        else
          # postgres
          c = { host: cx.host, database: cx.db, username: cx.user, password: cx.pass, port: cx.port, server: 'postgres' }
        end

        {
          'host' =>     c[:host],
          'database' => c[:database],
          'username' => c[:username],
          'password' => c[:password],
          'port' =>     c[:port],
          'server' =>   c[:server],
        }
    end

    protected

    def self.start_watcher
      path = log_path
      if ENV['SHIBA_DEBUG']
        $stderr.puts("starting shiba watcher, outputting to #{path}")
      end

      file = File.open(path, 'a')
      watcher = QueryWatcher.new(file)

      ActiveSupport::Notifications.subscribe('sql.active_record', watcher)
      when_done { run_explain(file, path) }
    rescue => e
      $stderr.puts("Shiba failed to load")
      $stderr.puts(e.message, e.backtrace.join("\n"))
    end

    def self.log_path
      name = ENV["SHIBA_QUERY_LOG_NAME"] || "query.log-#{Time.now.to_i}"
      File.join(Shiba.path, name)
    end

    def self.when_done
      return false if @done_hook

      # define both minitest and rspec hooks -- it can be
      # unclear in some envs which one is active.  maybe even both could run in one process?  not sure.
      shiba_done = false
      if defined?(Minitest.after_run)
        MiniTest.after_run do
          yield unless shiba_done
          shiba_done = true
        end
        @done_hook = :minitest
      end

      if defined?(RSpec.configure)
        RSpec.configure do |config|
          config.after(:suite) do
            yield unless shiba_done
            shiba_done = true
          end
        end
        @done_hook = :rspec
      end

      if !@done_hook
        $stderr.puts "Warning: shiba could not find Minitest or RSpec."
        $stderr.puts "If tests are running with one of these libraries, ensure shiba is required after them."
        at_exit { yield }
        @done_hook = :at_exit
      end
    end

    def self.run_explain(file, path)
      file.close

      cmd = "shiba explain #{database_args} --file #{path}"
      if ENV['SHIBA_QUERY_LOG_NAME']
        cmd << " --json #{File.join(Shiba.path, "#{ENV["SHIBA_QUERY_LOG_NAME"]}.json")}"
      elsif Shiba::Configure.ci?
        cmd << " --json #{File.join(Shiba.path, 'ci.json')}"
      end

      if ENV['SHIBA_DEBUG']
        $stderr.puts("running:")
        $stderr.puts(cmd)
      end
      system(cmd)
    end

    def self.database_args
      # port can be a Fixnum
      connection_options.reject { |k,v| v.nil? || v.respond_to?(:empty?) && v.empty? }.map { |k,v| "--#{k} #{v}" }.join(" ")
    end

  end
end
