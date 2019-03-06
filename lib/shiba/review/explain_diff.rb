require 'json'
require 'open3'

require 'shiba/review/diff_parser'
require 'shiba/backtrace'

module Shiba
  module Review
    # Given an explain log and a diff, returns any explain logs
    # that appear to be caused by the diff.
    class ExplainDiff
      Result = Struct.new(:status, :message, :problems)

      attr_reader :options

      def initialize(options)
        @options = options
      end

      # Returns a Result object with a status, message, and any problem queries detected.
      # Query problem format is [ [ "path:lineno", explain ]... ]
      def explains(log)
        msg = nil

        if options['verbose']
          puts cmd
        end

        if changed_files.empty?
          if options['verbose']
            msg = "No changes found. Are you sure you specified the correct branch?"
          end
          return Result.new(:pass, msg)
        end

        explains = select_lines_with_changed_files(log)
        problems = explains.select { |explain| explain["severity"] && explain["severity"] != 'none' }

        if options["verbose"]
          puts problems
          puts "Updated lines: #{updated_lines}"
        end

        if problems.empty?
          msg = "No problems found caused by the diff"
          return Result.new(:pass, msg)
        end

        problems.map! do |problem|
          line = updated_line_from_backtrace(problem["backtrace"], updated_lines)
          next if line.nil?

          [ line, problem ]
        end
        problems.compact!

        if problems.empty?
          msg = "No problems found caused by the diff"
          return Result.new(:pass, msg)
        end

        return Result.new(:fail, "Potential problems", problems)
      end

      protected

      def updated_line_from_backtrace(backtrace, updates)
        backtrace.each do |bl|
          updates.each do |path, lines|
            next if !bl.start_with?(path)
            bl =~ /:(\d+):/
            next if !lines.include?($1.to_i)

            return "#{path}:#{$1}"
          end
        end

        return nil
      end

      def select_lines_with_changed_files(log)
        patterns = changed_files.map { |path| "-e #{path}" }.join(" ")
        cmd = "grep #{log} #{patterns}"
        $stderr.puts cmd if options["verbose"]

        json_lines = `#{cmd}`
        json_lines.each_line.map { |line| JSON.parse(line) }
      end

      def changed_files
        @changed_files ||= begin
          options['diff'] ? file_diff_names : git_diff_names
        end
      end

      def updated_lines
        return @updated_lines if @updated_lines


        out = options['diff'] ? file_diff_lines : git_diff_lines
        @updated_lines = Shiba::Review::DiffParser.new(out).updated_lines


        @updated_lines.map! do |path, lines|
          [ Shiba::Backtrace.clean!(path), lines ]
        end
      end

      def file_diff_lines
        File.open(options['diff'])
      end

      def git_diff_lines
        run = "git diff#{cmd} --unified=0 --diff-filter=d"
        if options[:verbose]
          $stderr.puts run
        end

        _, out,_,_ = Open3.popen3(run)
        out
      end

      # index ade9b24..661d522 100644
      # --- a/test/app/app.rb
      # +++ b/test/app/app.rb
      # @@ -24,4 +24,4 @@ ActiveRecord::Base...
      # org = Organization.create!(name: 'test')
      #
      # file_diff_lines
      # => test/app/app.rb
      def file_diff_names
        file_name_pattern = /^\+\+\+ b\/(.*?)$/
        f = File.open(options['diff'])
        f.grep(file_name_pattern) { $1 }
      end

      def git_diff_names
        run = "git diff#{cmd} --name-only --diff-filter=d"

        if options[:verbose]
          $stderr.puts run
        end
        result = `#{run}`
        if $?.exitstatus != 0
          $stderr.puts result
          raise Shiba::Error.new "Failed to read changes"
        end

        result.split("\n")
      end

      def cmd
        cmd = case
        when options["staged"]
          " --staged"
        when options["unstaged"]
          ""
        else
          commit = " origin/HEAD"
          commit << "...#{options["branch"]}" if options["branch"]
          commit
        end
      end

    end
  end
end