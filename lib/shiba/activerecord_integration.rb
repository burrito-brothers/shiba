require 'shiba/query_watcher'
require 'active_support/notifications'
require 'active_support/lazy_load_hooks'

module Shiba
  # Integrates ActiveRecord with the Query Watcher by setting up the query log path, and the
  # connection options for the explain command, which it runs when the process exits.
  #
  # SHIBA_OUT=<log path> and SHIBA_DEBUG=true environment variables may be set.
  class ActiveRecordIntegration

    attr_reader :path, :watcher

    def self.install!
      return false if @installed

      ActiveSupport.on_load(:active_record) do
        Shiba::ActiveRecordIntegration.start_watcher
      end

      @installed = true
    end

    protected

    def self.start_watcher
      if ENV['SHIBA_DEBUG']
        $stderr.puts("starting shiba watcher")
      end

      path = ENV['SHIBA_OUT'] || make_tmp_path

      file = File.open(path, 'a')
      watcher = QueryWatcher.new(file)

      ActiveSupport::Notifications.subscribe('sql.active_record', watcher)
      at_exit { run_explain(file, path) }
    rescue => e
      $stderr.puts("Shiba failed to load")
      $stderr.puts(e.message, e.backtrace.join("\n"))
    end

    def self.make_tmp_path
      "/tmp/shiba-query.log-#{Time.now.to_i}"
    end

    def self.run_explain(file, path)
      file.close
      puts ""
      cmd = "shiba explain #{database_args} --file #{path}"
      if ENV['SHIBA_DEBUG']
        $stderr.puts("running:")
        $stderr.puts(cmd)
      end
      system(cmd)
    end

    def self.database_args
      c = ActiveRecord::Base.connection.raw_connection.query_options
      options = {
      'host':     c[:host],
      'database': c[:database],
      'user':     c[:username],
      'password': c[:password]
      }

      options.reject { |k,v| v.nil? }.map { |k,v| "--#{k} #{v}" }.join(" ")
    end

  end
end