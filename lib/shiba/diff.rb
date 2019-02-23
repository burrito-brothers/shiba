module Shiba
  class Diff
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
end