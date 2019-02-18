require 'json'
require 'open3'

require 'shiba/diff'
require 'shiba/backtrace'

module Shiba
  class Checker
    MAGIC_COST = 100

    Result = Struct.new(:status, :message, :problems)

    attr_reader :options

    def initialize(options)
      @options = options
    end

    # Returns a Result object with a status, message, and any problem queries detected.
    # Query problem format is [ [ "path:lineno", explain ]... ]
    def run(log)
      msg = nil

      if options['verbose']
        puts cmd
      end

      if changes.empty?
        if options['verbose']
          msg = "No changes found in git. Are you sure you specified the correct branch?"
        end
        return Result.new(:pass, msg)
      end

      explains = select_lines_with_changed_files(log)
      problems = explains.select { |explain| explain["cost"] && explain["cost"] > MAGIC_COST }

      if options["verbose"]
        puts problems
      end

      if options["verbose"]
        puts updated_lines
      end

      problems.map! do |problem|
        line = updated_line_from_backtrace(problem["backtrace"], updated_lines)
        next if line.nil?

        [ line, problem ]
      end
      problems.compact!

      if problems.empty?
        if options['verbose']
          msg = "No problems found"
        end

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
      patterns = changes.split("\n").map { |path| "-e #{path}" }.join(" ")
      cmd = "grep #{log} #{patterns}"
      $stderr.puts cmd if options["verbose"]

      json_lines = `#{cmd}`
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