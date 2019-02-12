require 'json'
require 'open3'

require 'shiba/diff'
require 'shiba/backtrace'

module Shiba
  class Checker
    Result = Struct.new(:status, :message, :problems)

    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run(log)
      msg = nil

      if options['verbose']
        puts cmd
      end

      if changes.empty?
        if options['verbose']
          msg = "No changes found in git"
        end
        return Result.new(:pass, msg)
      end

      explains = select_lines_with_changed_files(log)
      problems = explains.select { |explain| explain["cost"] && explain["cost"] > MAGIC_COST }

      problems.select! do |problem|
        backtrace_has_updated_line?(problem["backtrace"], updated_lines)
      end

      if problems.empty?
        if options['verbose']
          msg = "No problems found"
        end

        return Result.new(:pass, msg)
      end

      return Result.new(:fail, "Potential problems", problems)
    end

    protected

    def backtrace_has_updated_line?(backtrace, updates)
      backtrace.any? do |bl|
        updates.any? do |path, lines|
          next if !bl.start_with?(path)
          bl =~ /:(\d+):/
          lines.include?($1.to_i)
        end
      end
    end

    def select_lines_with_changed_files(log)
      patterns = changes.split("\n").map { |path| "-e #{path}" }.join(" ")
      json_lines = `grep #{log} #{patterns}`
      json_lines.each_line.map { |line| JSON.parse(line) }
    end

    def changes
      @changes ||= begin
        result = `git diff#{cmd} --name-only --diff-filter=d`
        if $?.exitstatus != 0
          error("Failed to read changes", $?.exitstatus)
        end

        result
      end
    end

    def updated_lines
      return @updated_lines if @updated_lines

      Open3.popen3("git diff#{cmd} --unified=0 --diff-filter=d") {|_,o,_,_|
        @updated_lines = Shiba::Diff.new(o).updated_lines
      }

      @updated_lines.map! do |path, lines|
        [ Shiba::Backtrace.clean!(path), lines ]
      end
    end

    def cmd
      cmd = case
      when options["staged"]
        " --staged"
      when options["unstaged"]
        ""
      else
        commit = " HEAD"
        commit << "...#{options["branch"]}" if options["branch"]
        commit
      end
    end
  end
end