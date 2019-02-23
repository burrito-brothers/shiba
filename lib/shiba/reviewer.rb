require 'open3'
require 'shiba'
require 'shiba/diff'
require 'shiba/review/api'
require 'shiba/review/comment_renderer'

module Shiba
  # TODO:
  # 1. Properly handle more than a handful of review failures
  # 2. May make sense to edit the comment on a commit line when the code
  # is semi-corrected but still a problem
  class Reviewer
    TEMPLATE_FILE = File.join(Shiba.root, 'lib/shiba/output/tags.yaml')

    attr_reader :repo_url, :problems, :options

    def initialize(repo_url, problems, options)
      @repo_url = repo_url
      @problems = problems
      @options = options
      @commit_id = options.fetch("branch") do
        raise Shiba::Error.new("Must specify a branch") if !options['diff']
      end
    end

    def comments
      return @comments if @comments

      @comments = problems.map do |path, explain|
        file, line_number = path.split(":")
        if path.empty? || line_number.nil?
          raise Shiba::Error.new("Bad path received: #{line_number}")
        end

        position = diff.find_position(file, line_number.to_i)

        if options["submit"]
          explain = keep_only_dangerous_messages(explain)
        end

        { body: renderer.render(explain),
          commit_id: @commit_id,
          path: file,
          line: line_number,
          position: position }
      end
    end

    # FIXME: Only submit 10 comments for now. The rest just vanish.
    # Submits commits, checking to makre sure the line doesn't already have a review.
    def submit
      report("Connecting to #{api.uri}")

      api.connect do
        previous_reviews = api.previous_comments.map { |c| c['body'] }

        comments[0,10].each do |c|
          if previous_reviews.any? { |r| r == c[:body] }
            report("skipped duplicate comment")
            next
          end

          # :line isn't part of the github api
          comment = c.dup.tap { |dc| dc.delete(:line) }
          if options[:verbose]
            comment[:body] += " (verbose mode ts=#{Time.now.to_i})"
          end

          res = api.comment_on_pull_request(comment)
          report("API success #{res.inspect}")
        end
      end

      report("HTTP request finished")
    end

    def repo_host
      @repo_host ||= api.host_and_path.first
    end

    def repo_path
      @repo_path ||= api.host_and_path.last
    end

    protected

    def report(message)
      if options["verbose"]
        $stderr.puts message
      end
    end

    def keep_only_dangerous_messages(explain)
      explain_b = explain.dup
      explain_b["messages"] = explain_b["messages"].select do |message|
        tag = message['tag']
        tags[tag]["level"] == "danger"
      end
      explain_b
    end

    def diff
      return @diff if @diff
      output = options['diff'] ? file_diff : git_diff
      @diff = Shiba::Diff.new(output)
    end

    def git_diff
      cmd ="git diff origin/HEAD..#{@commit_id}"
      report("Finding PR position using: #{cmd}")

      output = StringIO.new(`#{cmd}`)
    end

    def file_diff
      report("Finding PR position using file: #{options['diff']}")
      File.open(options['diff'], 'r')
    end

    def api
      @api ||= begin
        api_options = {
          "token"        => options["token"],
          "pull_request" => options["pull_request"]
        }
        Review::API.new(repo_url, api_options)
      end
    end

    def renderer
      @renderer ||= Review::CommentRenderer.new(tags)
    end

    def tags
      @tags ||=  YAML.load_file(TEMPLATE_FILE)
    end

  end
end
