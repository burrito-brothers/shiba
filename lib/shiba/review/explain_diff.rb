require 'json'
require 'open3'

require 'shiba/review/diff'
require 'shiba/backtrace'

module Shiba
  module Review
    # Given an explain log and a diff, returns any explain logs
    # that appear to be caused by the diff.
    class ExplainDiff
      Result = Struct.new(:status, :message)

      attr_reader :options

      def initialize(log, options)
        @log     = log
        @options = options
      end

      def diff_requested_by_user?
        [ "staged", "unstaged", "branch", "diff" ].any? { |key| @options.key?(key) }
      end

      # Returns detected problem queries with their line numbers.
      # Query problem format is [ [ "path:lineno", explain ]... ]
      def problems
        return @problems if @problems

        @problems = explains_with_backtrace_in_diff.select do |explain|
          explain["severity"] && explain["severity"] != 'none'
        end

        if options["verbose"]
          $stderr.puts @problems
          $stderr.puts "Updated lines: #{updated_lines}"
        end

        @problems.map! do |problem|
          line = diff_line_from_backtrace(problem["backtrace"])
          next if line.nil?

          [ line, problem ]
        end
        @problems.compact!

        @problems
      end

      def result
        msg = nil

        if changed_files.empty?
          if options['verbose']
            msg = "No changes found. Are you sure you specified the correct branch?"
          end
          return Result.new(:pass, msg)
        end

        if problems.empty?
          msg = "No problems found caused by the diff"
          return Result.new(:pass, msg)
        end

        return Result.new(:fail, "Potential problems")
      end

      protected

      # file.rb:32:in `hello'",
      LINE_NUMBER_PATTERN = /:(\d+):/

      def diff_line_from_backtrace(backtrace)
        backtrace.each do |bl|
          updated_lines.each do |path, lines|
            next if !bl.start_with?(path)
            bl =~ LINE_NUMBER_PATTERN
            next if !lines.include?($1.to_i)

            return "#{path}:#{$1}"
          end
        end

        return nil
      end

      # All explains from the log file with a backtrace that contains a changed file.
      def explains_with_backtrace_in_diff
        patterns = changed_files.map { |path| "-e #{path}" }.join(" ")
        cmd = "grep #{@log} #{patterns}"
        $stderr.puts cmd if options["verbose"]

        json_lines = `#{cmd}`
        json_lines.each_line.map { |line| JSON.parse(line) }
      end

      def changed_files
        @changed_files ||= diff.paths
      end

      def updated_lines
        return @updated_lines if @updated_lines

        diff_file = diff.file(context: 0, ignore_deletions: true)
        @updated_lines = Diff::Parser.new(diff_file).updated_lines
        @updated_lines.map! do |path, lines|
          [ Shiba::Backtrace.clean!(path), lines ]
        end
      end

      def diff
        @diff ||= options["diff"] ? Diff::FileDiff.new(options["diff"]) : Diff::GitDiff.new(options)
      end

    end
  end
end