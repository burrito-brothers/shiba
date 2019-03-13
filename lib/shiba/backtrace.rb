require 'open3'

module Shiba
  module Backtrace

    BACKTRACE_SIZE = 8
    def self.ignore
      @ignore ||= [ '.rvm', 'gem', 'vendor', 'rbenv', 'seed',
        'db', 'test', 'spec', 'lib/shiba' ]
    end

    # 8 backtrace lines starting from the app caller, cleaned of app/project cruft.
    def self.from_app
      locations = caller_locations

      bt = []
      locations.each do |loc|
        line = loc.to_s
        if bt.empty?
          bt << clean!(line) unless line =~ ignore_pattern
        else
          line = clean!(line)
          bt << line
        end
      end
      bt.any? && bt
    end

    def self.clean!(line)
      line.sub!(backtrace_clean_pattern, '')
      line
    end

    protected

    IGNORE_GEMS = %w(activesupport railties activerecord actionpack rake rspec-core factory_bot rspec-rails)

    def self.reject_gem?(line)
      @gem_regexp ||= Regexp.new("gems/(" + IGNORE_GEMS.join("|") + ")")
      line =~ @gem_regexp
    end

    def self.reject?(line)
      reject_gem?(line) ||
        line =~ %r{core_ext/kernel_require.rb} ||
        line =~ %r{mon_synchronize}
    end

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
