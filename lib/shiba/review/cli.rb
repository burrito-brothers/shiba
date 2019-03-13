require 'optionparser'
require 'shiba/configure'
require 'shiba/reviewer'
require 'shiba/review/explain_diff'
require 'json'

module Shiba
  module Review
    # Builds options for interacting with the reviewer via the command line.
    # Automatically infers options from environment variables on CI.
    #
    # Example:
    # cli = CLI.new
    # cli.valid?
    # => true
    # cli.options
    # => { "file" => 'path/to/explain_log.json' }
    #
    # or
    #
    # cli.valid?
    # => false
    # cli.failure
    # => "An error message with command line help."
    class CLI

      attr_reader :out, :err, :input

      # Options may be provided for testing, in which case the option parser is skipped.
      # When this happens, default options are also skipped.
      def initialize(out: $stdout, err: $stderr, input: $stdin, options: nil)
        @out = out
        @err = err
        @input = input
        @user_options = options || {}
        @errors = []
        parser.parse! if options.nil?
        @options = options || default_options.merge(@user_options)
      end

      # Generates the review, returning an exit status code.
      # Prints to @out / @err, which default to STDOUT/STDERR.
      def run
        report_options("diff", "branch", "pull_request")

        if !valid?
          err.puts failure
          return 1
        end

        explain_diff = Shiba::Review::ExplainDiff.new(options["file"], options)

        problems = if explain_diff.diff_requested_by_user?
          result = explain_diff.result

          if result.message
            @err.puts result.message
          end

          if result.status == :pass
            return 0
          end

          explain_diff.problems
        else
          # Find all problem explains
          begin
            explains = explain_file.each_line.map { |json| JSON.parse(json) }
            bad = explains.select { |explain| explain["severity"] && explain["severity"] != 'none' }
            bad.map { |explain| [ "#{explain["sql"]}:-2", explain ] }
          rescue Interrupt
            @err.puts "SIGINT: Canceled reading from STDIN. To read from an explain log, provide the --file option."
            exit 1
          end
        end

        if problems.empty?
          return 0
        end

        # Dedup
        problems.uniq! { |_,p| p["md5"] }

        # Output problem explains, this can be provided as a file to shiba review for comments.
        if options["raw"]
          pr = options["pull_request"]
          if pr
            problems.each { |_,problem| problem["pull_request"] = pr }
          end


          problems.each { |_,problem| @out.puts JSON.dump(problem) }
          return 2
        end

        # Generate comments for the problem queries
        repo_cmd = "git config --get remote.origin.url"
        repo_url = `#{repo_cmd}`.chomp

        if options["verbose"]
          @err.puts "#{repo_cmd}\t#{repo_url}"
        end

        if repo_url.empty?
          @err.puts "'#{Dir.pwd}' does not appear to be a git repo"
          return 1
        end

        reviewer = Shiba::Reviewer.new(repo_url, problems, options)

        if !options["submit"] || options["verbose"]
          reviewer.comments.each do |c|
            @out.puts "#{c[:path]}:#{c[:line]} (#{c[:position]})"
            @out.puts c[:body]
            @out.puts ""
          end
        end

        if options["submit"]
          if reviewer.repo_host.empty? || reviewer.repo_path.empty?
            @err.puts "Invalid repo url '#{repo_url}' from git config --get remote.origin.url"
            return 1
          end

          reviewer.submit
        end

        return 2
      end

      def options
        @options
      end

      def valid?
        return false if @errors.any?

        validate_log_path
        #validate_git_repo if branch || options["submit"]

        if options["submit"]
          require_option("branch") if options["diff"].nil?
          require_option("token", description: "This can be read from the $SHIBA_GITHUB_TOKEN environment variable.")
          require_option("pull_request")
          error("Must specify either 'submit' or 'raw' output option, not both") if options["raw"]
        end

        @errors.empty?
      end

      def failure
        return nil if @errors.empty?

        message, help = @errors.first
        message += "\n"
        if help
          message += "\n#{parser}"
        end

        message
      end

      def report_options(*keys)
        keys.each do |key|
          report("#{key}: #{options[key]}")
        end
      end

      protected

      def explain_file
        options.key?('file') ? File.open(options['file']) : @input
      end

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Reads from a file or stdin to review changes for query problems. Optionally submit the comments to a Github pull request."

          opts.separator ""
          opts.separator "IO options:"

          opts.on("-f","--file FILE", "The JSON explain log to compare with. Automatically configured when $CI environment variable is set") do |f|
            @user_options["file"] = f
          end

          opts.on("--raw", "Print the raw JSON with the pull request id") do |r|
            @user_options["raw"] = r
          end

          opts.separator ""
          opts.separator "Git diff options:"

          opts.on("-b", "--branch GIT_BRANCH", "Compare to changes between origin/HEAD and BRANCH. Attempts to read from CI environment when not set.") do |b|
            @user_options["branch"] = b
          end

          opts.on("--staged", "Only check files that are staged for commit") do
            @user_options["staged"] = true
          end

          opts.on("--unstaged", "Only check files that are not staged for commit") do
            @user_options["unstaged"] = true
          end

          opts.separator ""
          opts.separator "Github options:"

          opts.on("--submit", "Submit comments to Github") do
            @user_options["submit"] = true
          end

          opts.on("-p", "--pull-request PR_ID", "The ID of the pull request to comment on. Attempts to read from CI environment when not set.") do |p|
            @user_options["pull_request"] = p
          end

          opts.on("-t", "--token TOKEN", "The Github API token to use for commenting. Defaults to $SHIBA_GITHUB_TOKEN.") do |t|
            @user_options["token"] = t
          end

          opts.separator ""
          opts.separator "Common options:"

          opts.on("--verbose", "Verbose/debug mode") do
            @user_options["verbose"] = true
          end

          opts.on_tail("-h", "--help", "Show this message") do
            @out.puts opts
            exit
          end

          opts.on_tail("--version", "Show version") do
            require 'shiba/version'
            @out.puts Shiba::VERSION
            exit
          end
        end
      end

      def default_options
        defaults = {}

        if ENV['DIFF']
          defaults['diff'] = ENV['DIFF']
        end

        if Shiba::Configure.ci?
          report("Finding default options from CI environment.")

          defaults["file"]         = ci_explain_log_path if ci_explain_log_path
          defaults["pull_request"] = ci_pull_request     if ci_pull_request
          defaults["branch"]       = ci_branch           if !defaults['diff'] && ci_branch
        end

        defaults["token"] = ENV['SHIBA_GITHUB_TOKEN'] if ENV['SHIBA_GITHUB_TOKEN']

        defaults
      end

      def validate_log_path
        return if !options["file"]
        if !File.exist?(options["file"])
          error("File not found: '#{options["file"]}'")
        end
      end

      def ci_explain_log_path
        name = ENV['SHIBA_QUERY_LOG_NAME'] || 'ci'
        File.join(Shiba.path, "#{name}.json")
      end

      def ci_branch
        ENV['TRAVIS_PULL_REQUEST_SHA'] || ENV['CIRCLE_SHA1']
      end

      def ci_pull_request
        ENV['TRAVIS_PULL_REQUEST'] || circle_pr_number
      end

      def circle_pr_number
        return if ENV["CIRCLE_PULL_REQUEST"].nil?
        number = URI.parse(ENV["CIRCLE_PULL_REQUEST"]).path.split("/").last
        return if number !~ /\A[0-9]+\Z/

        number
      end

      def require_option(name, description: nil)
        return true if options.key?(name)
        msg = "Required: '#{name}'"
        msg << ". #{description}" if description
        error(msg, help: true)
      end

      def report(message)
        @err.puts message if @user_options["verbose"]
      end

      def error(message, help: false)
        @errors << [ message, help ]
      end

    end
  end
end