require 'shiba/query_watcher'

class Shiba::Railtie < Rails::Railtie
  # Logging is enabled when:
  #  1. SHIBA_OUT environment variable is set to an existing file path.
  #  2. RSpec/MiniTest exists, in which case a fallback query log is generated at /tmp
  config.after_initialize do
    begin
      path = ENV['SHIBA_OUT'] || "/tmp/shiba-query.log-#{Time.now.to_i}"
      f = File.open(path, 'a')
      watcher = Shiba::QueryWatcher.watch(f)
      next if watcher.nil?

      at_exit do
        f.close
        puts ""
        cmd = "shiba explain #{database_args} --file #{path}"
        if ENV['SHIBA_DEBUG']
          $stderr.puts("running:")
          $stderr.puts(cmd)
        end
        system(cmd)
      end

    rescue => e
      $stderr.puts("Shiba failed to load")
      $stderr.puts(e.message, e.backtrace.join("\n"))
    end
  end

  def self.database_args
    c = ActiveRecord::Base.configurations['test']
    options = {
      'host':     c['host'],
      'database': c['database'],
      'user':     c['username'],
      'password': c['password']
    }

    options.reject { |k,v| v.nil? }.map { |k,v| "--#{k} #{v}" }.join(" ")
  end

end
