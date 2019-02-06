require 'shiba/query_watcher'

class Shiba::Railtie < Rails::Railtie
  # Logging is enabled when:
  #  1. SHIBA_OUT environment variable is set to an existing file path.
  #  2. RSpec/MiniTest exists, in which case a fallback query log is generated at /tmp
  config.after_initialize do
    path = ENV['SHIBA_OUT']

    if test_runners_defined?
      path ||= "/tmp/shiba-query.log-#{Time.now.to_i}"
    end

    next if path.nil?

    watcher = watch(path)
    next if watcher.nil?

    at_exit do
      puts ""
      explain_path = "/tmp/shiba-explain.log-#{Time.now.to_i}"
      cmd = "shiba explain #{database_args} --file #{path} --explain #{explain_path} --out /tmp/"
      system(cmd)
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

  def self.test_runners_defined?
    defined?(RSpec.configure) || defined?(MiniTest) || defined?(Test::Unit)
  end

  def self.watch(path)
    f = File.open(path, 'a')
    Shiba::QueryWatcher.watch(f)
  rescue => e
    $stderr.puts("Shiba failed to load")
    $stderr.puts(e.message, e.backtrace.join("\n"))
  end

end