require 'shiba/query_watcher'

class Shiba::Railtie < Rails::Railtie
  config.after_initialize do
    Shiba::QueryWatcher.watch
  end
end