require 'shiba/query_watcher'

class Shiba::Railtie < Rails::Railtie
  config.after_initialize do
    path = `mktemp /tmp/shiba-query.log-#{Time.now.to_i}`.chomp # ENV['SHIBA_OUT']
    next if !path

    watcher = log_queries(path)
    next if !watcher

    if defined?(RSpec)
      hook_into_rspec(path)
    end
  end

  def self.hook_into_rspec(path)
    RSpec.configure do |c|
      c.after(:suite) do
        puts ""
        system("shiba analyze --file #{path} --test")
      end
    end
  end

  def self.log_queries(path)
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