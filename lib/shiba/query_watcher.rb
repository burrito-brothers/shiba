require 'shiba/query'
require 'json'
require 'logger'
require 'rails'

module Shiba
  # TO use, put this line in config/initializers: Shiba::QueryWatcher.watch
  module QueryWatcher
    FINGERPRINTS = {}
    IGNORE = /\.rvm|gem|vendor\/|rbenv|seed|db|shiba|test|spec/

    def self.make_logger(fname)
      FileUtils.touch fname
      Logger.new(fname).tap do |l|
        l.formatter = proc do |severity, datetime, progname, msg|
          "#{msg}\n"
        end
      end
    end

    def self.cleaned_explain(h)
      h.except("id", "select_type", "partitions", "type")
    end

    def self.logger
      @logger ||= make_logger('shiba.log.json')
    end

    # Logs ActiveRecord SELECT queries that originate from application code.
    def self.watch
      Shiba.configure(ActiveRecord::Base.configurations["test"])

      ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        sql = payload[:sql]
        # fixme: add table stats
        query = Shiba::Query.new(sql, {})

        if sql.start_with?("SELECT") && !FINGERPRINTS[query.fingerprint]
          lines = app_backtrace

          if lines
            # fixme don't take down the app when explain goes bad.
            explain = query.explain
            json = JSON.dump(sql: sql, explain: cleaned_explain(explain.to_h), backtrace: lines, cost: explain.cost)
            logger.info(json)
          end

          FINGERPRINTS[query.fingerprint] = true
        end
      end
    end

    # 8 backtrace lines starting from the app caller, cleaned of app/project cruft.
    def self.app_backtrace
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

    def self.backtrace_ignore_pattern
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
    def self.repo_root
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
