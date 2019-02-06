require 'shiba/query'
require 'json'
require 'rails'

module Shiba
  class QueryWatcher
    IGNORE = /\.rvm|gem|vendor\/|rbenv|seed|db|shiba|test|spec/

    def self.watch(file)
      new(file).tap { |w| w.watch }
    end

    attr_reader :queries

    def initialize(file)
      @file = file
      # fixme mem growth on this is kinda nasty
      @queries = {}
    end

    # Logs ActiveRecord SELECT queries that originate from application code.
    def watch
      ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        sql = payload[:sql]

        if sql.start_with?("SELECT")
          fingerprint = Query.get_fingerprint(sql)
          if !@queries[fingerprint]
            if lines = app_backtrace
              @file.puts("#{sql} /*shiba#{lines}*/")
            end
          end
          @queries[fingerprint] = true
        end
      end
    end

    protected

    # 8 backtrace lines starting from the app caller, cleaned of app/project cruft.
    def app_backtrace
      app_line_idx = caller_locations.index { |line| line.to_s !~ IGNORE }
      if app_line_idx == nil
        return
      end

      caller_locations(app_line_idx+1, 8).map do |loc|
        line = loc.to_s
        line.sub!(backtrace_ignore_pattern, '')
        line
      end
    end

    def backtrace_ignore_pattern
      @roots ||= begin
        paths = Gem.path
        paths << Rails.root.to_s if Rails.root
        paths << repo_root
        paths << ENV['HOME']
        paths.uniq!
        paths.compact!
        # match and replace longest path first
        paths.sort_by!(&:size).reverse!

        Regexp.new(paths.map {|r| Regexp.escape(r) }.join("|"))
      end
    end

    # /user/git_repo => "/user/git_repo"
    # /user/not_a_repo => nil
    def repo_root
      root = nil
      Open3.popen3('git rev-parse --show-toplevel') {|_,o,_,_|
        if root = o.gets
          root = root.chomp
        end
      }
      root
    end

  end
end
