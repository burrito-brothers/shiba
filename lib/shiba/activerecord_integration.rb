require 'shiba/query_watcher'
require 'active_support/notifications'
require 'active_support/lazy_load_hooks'
require 'shiba/configure'

module Shiba
  # Integrates ActiveRecord with the Query Watcher by setting up the query log path, and the
  # connection options for the explain command, which it runs when the process exits.
  #
  # SHIBA_OUT and SHIBA_DEBUG=true environment variables may be set.
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
      path = log_path
      if ENV['SHIBA_DEBUG']
        $stderr.puts("starting shiba watcher, outputting to #{path}")
      end

      file = File.open(path, 'a')
      watcher = QueryWatcher.new(file)

      ActiveSupport::Notifications.subscribe('sql.active_record', watcher)
      at_exit { run_explain(file, path) }
    rescue => e
      $stderr.puts("Shiba failed to load")
      $stderr.puts(e.message, e.backtrace.join("\n"))
    end

    def self.log_path
      name = ENV["SHIBA_OUT"] || "query.log-#{Time.now.to_i}"
      File.join(Shiba.path, name)
    end

    def self.run_explain(file, path)
      file.close
      puts ""

      cmd = "shiba explain #{database_args} --file #{path}"
      if Shiba::Configure.ci?
        cmd << " --json #{File.join(Shiba.path, 'ci.json')}"
      elsif ENV['SHIBA_OUT']
        cmd << " --json #{File.join(Shiba.path, "#{ENV["SHIBA_OUT"]}.json")}"
      end

      if ENV['SHIBA_DEBUG']
        $stderr.puts("running:")
        $stderr.puts(cmd)
      end
      system(cmd)
    end

    def self.database_args
      cx = ActiveRecord::Base.connection.raw_connection
      if cx.respond_to?(:query_options)
        # mysql
        c = cx.query_options.merge(server: 'mysql')
      else
        # postgres
        c = { host: cx.host, database: cx.db, username: cx.user, password: cx.pass, port: cx.port, server: 'postgres' }
      end

      options = {
        'host':     c[:host],
        'database': c[:database],
        'user':     c[:username],
        'password': c[:password],
        'port':     c[:port],
        'server':   c[:server]
      }

      # port can be a Fixnum
      options.reject { |k,v| v.nil? || v.respond_to?(:empty?) && v.empty? }.map { |k,v| "--#{k} #{v}" }.join(" ")
    end

  end
end
