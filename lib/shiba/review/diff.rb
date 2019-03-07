module Shiba
  module Review
    module Diff

      class Parser
        # +++ b/config/environments/test.rb
        FILE_PATTERN = /\A\+\+\+ b\/(.*?)\Z/

        # @@ -177,0 +178 @@ ...
        # @@ -177,0 +178,5 @@ ...
        # @@ -21 +24 @@ ...
        LINE_PATTERN = /\A@@ \-\d+,?\d+? \+(\d+),?(\d+)? @@/

        # via https://developer.github.com/v3/pulls/comments/#create-a-comment
        # The position value equals the number of lines down from the first "@@" hunk header
        # in the file you want to add a comment.

        attr_reader :status

        def initialize(file)
          # Fixme. seems like enumerables should work in general.
          if !file.respond_to?(:pos)
            raise StandardError.new("Diff file does not appear to be a seekable IO object.")
          end
          @diff = file
          @status = :new
        end

        # Returns the file and line numbers that contain inserts. Deletions are ignored.
        # For simplicity, the default output of git diff is not supported.
        # The expected format is from 'git diff unified=0'
        #
        # Example:
        # diff = `git diff --unified=0`
        # Diff.new(StringIO.new(diff))
        # => [ [ "hello.rb", 1..3 ]
        # =>   [ "hello.rb", 7..7 ]
        # =>   [ "test.rb", 23..23 ]
        # => ]
        def updated_lines
          io = @diff.each_line
          path = nil

          found = []

          while true
            line = io.next
            if line =~ FILE_PATTERN
              path = $1
            end

            if hunk_header?(line)
              line_numbers = line_numbers_for_destination(line)
              found << [ path, line_numbers ]
            end
          end
        rescue StopIteration
          return found
        end

        # Returns the position in the diff, after the relevant file header,
        # that contains the specified file/lineno modification.
        # Only supports finding the position in the destination / newest version of the file.
        #
        # Example:
        # diff = Diff.new(`git diff`)
        # diff.find_position("test.rb", 3)
        # => 5
        def find_position(path, line_number)
          io = @diff.each_line # maybe redundant?

          file_header = "+++ b/#{path}\n" # fixme
          if !io.find_index(file_header)
            @status = :file_not_found
            return
          end

          line = io.peek
          if !hunk_header?(line)
            raise StandardError.new("Expected hunk header to be after file header, but got '#{line}'")
          end

          pos = 0

          while true
            line = io.next
            pos += 1

            if file_header?(line)
              @status = :line_not_found
              return
            end

            if !hunk_header?(line)
              next
            end

            line_numbers = line_numbers_for_destination(line)

            if destination_position = line_numbers.find_index(line_number)
              @status = :found_position
              return pos + find_hunk_index(io, destination_position)
            end
          end
        rescue StopIteration
          @status = :line_not_found
        end

        protected

        def find_hunk_index(hunk, pos)
          line, idx = hunk.with_index.select { |l,idx| !l.start_with?('-') }.take(pos+1).last
          idx
        end

        def file_header?(line)
          line =~ FILE_PATTERN
        end

        def hunk_header?(line)
          LINE_PATTERN =~ line
        end

        def line_numbers_for_destination(diff_line)
          diff_line =~ LINE_PATTERN
          line = $1.to_i
          line_count = ($2 && $2.to_i) || 0
          line..line+line_count
        end
      end

      class GitDiff

        # Valid options are: "staged", "unstaged", "branch", and "verbose"
        def initialize(options)
          @options = options
        end

        def paths
          if options['verbose']
            puts cmd
          end

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

        # Differ expects context: 0, ignore_deletions: true
        def file(context: nil, ignore_deletions: false)
          differ = "git diff#{cmd}"
          differ << " --unified=#{context}" if context
          differ << " --diff-filter=d"      if ignore_deletions
          run(differ)
        end

        protected

        attr_reader :options

        def run(command)
          if options[:verbose]
            $stderr.puts command
          end

          _, out,_,_ = Open3.popen3(command)
          out
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

      class FileDiff
        # +++ b/test/app/app.rb
        FILE_NAME_PATTERN = /^\+\+\+ b\/(.*?)$/

        def initialize(path)
          @path = path
        end

        # Extracts path names from the diff file
        #
        # Example:
        # index ade9b24..661d522 100644
        # --- a/test/app/app.rb
        # +++ b/test/app/app.rb
        # @@ -24,4 +24,4 @@ ActiveRecord::Base...
        # org = Organization.create!(name: 'test')
        #
        # diff.paths
        # => [ test/app/app.rb ]
        def paths
          f = File.open(@path)
          f.grep(FILE_NAME_PATTERN) { $1 }
        end

        def file(context: nil, ignore_deletions: nil)
          warn "Context not supported for file diffs" if context
          warn "Ignore deletions not supported for file diffs" if ignore_deletions
          File.open(@path)
        end

      end

    end
  end
end