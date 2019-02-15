require 'open3'

module Shiba
  module Backtrace

    def self.ignore
      @ignore ||= [ '.rvm', 'gem', 'vendor', 'rbenv', 'seed',
        'db', 'test', 'spec', 'lib/shiba' ]
    end

    # 8 backtrace lines starting from the app caller, cleaned of app/project cruft.
    def self.from_app
      app_line_idx = caller_locations.index { |line| line.to_s !~ ignore_pattern }
      if app_line_idx == nil
        return
      end

      caller_locations(app_line_idx+1, 8).map do |loc|
        clean!(loc.to_s)
      end
    end

    def self.clean!(line)
      line.sub!(backtrace_clean_pattern, '')
      line
    end

    protected

    def self.ignore_pattern
      @pattern ||= Regexp.new(ignore.map { |word| Regexp.escape(word) }.join("|"))
    end

    def self.backtrace_clean_pattern
      @backtrace_clean_pattern ||= begin
        paths = Gem.path
        paths << Rails.root.to_s if defined?(Rails.root)
        paths << repo_root
        paths << ENV['HOME']
        paths.uniq!
        paths.compact!
        # match and replace longest path first
        paths.sort_by!(&:size).reverse!

        r = Regexp.new(paths.map {|r| Regexp.escape(r) }.join("|"))
        # kill leading slash
        /(#{r})\/?/
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