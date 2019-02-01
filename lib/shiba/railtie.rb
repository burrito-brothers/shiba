require 'shiba/query_watcher'

class Shiba::Railtie < Rails::Railtie
  config.after_initialize do
    begin
      path = ENV['SHIBA_OUT']
      next if !path

      if File.exist?(path)
        f = File.open(path, 'a')
        Shiba::QueryWatcher.watch(f)
      else
        $stderr.puts("Shiba could not open '#{path}' for logging.")
      end
    rescue => e
      $stderr.puts("Shiba failed to load")
      $stderr.puts(e.message, e.backtrace.join("\n"))
    end
  end
end