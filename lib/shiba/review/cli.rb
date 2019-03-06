module Shiba
  module Review
    # Builds options for interacting with the reviewer via the command line.
    # Automatically infers options from environment variables on CI.
    #
    # Example:
    # cli = CLI.build
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

      def self.build
        cli = new
        cli.report_options("diff", "branch", "pull_request")
        cli
      end

      attr_reader :errors

      def initialize
        @user_options = {}
        @errors = []
        parser.parse!
        @options = default_options.merge(@user_options)
      end

      def options
        @options
      end

      def valid?
        return false if @errors.any?

        validate_log_path
        #validate_git_repo if branch || options["submit"]
        description = "Provide an explain log, or run 'shiba explain' to generate one."

        require_option("file", description: description)

        if options["submit"]
          require_option("branch") if options["diff"].nil?
          require_option("token")
          require_option("pull_request")
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

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Review changes for query problems. Optionally submit the comments to a Github pull request."

          opts.separator "Required:"

          opts.on("-f","--file FILE", "The explain output log to compare with. Automatically configured when $CI environment variable is set") do |f|
            @user_options["file"] = f
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

          opts.on("-t", "--token TOKEN", "The Github API token to use for commenting. Defaults to $GITHUB_TOKEN.") do |t|
            @user_options["token"] = t
          end

          opts.separator ""
          opts.separator "Common options:"

          opts.on("--verbose", "Verbose/debug mode") do
            @user_options["verbose"] = true
          end

          opts.on_tail("-h", "--help", "Show this message") do
            puts opts
            exit
          end

          opts.on_tail("--version", "Show version") do
            require 'shiba/version'
            puts Shiba::VERSION
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

          defaults["file"]         = ci_explain_log_path
          defaults["pull_request"] = ci_pull_request
          defaults["branch"]       = ci_branch if !defaults['diff']
        end

        defaults["token"] = ENV['GITHUB_TOKEN'] if ENV['GITHUB_TOKEN']

        defaults
      end

      def validate_log_path
        return if !options["file"]
        if !File.exist?(options["file"])
          error("File not found: '#{options["file"]}'")
        end
      end

      def ci_explain_log_path
        File.join(Shiba.path, 'ci.json')
      end

      def ci_branch
        ENV['TRAVIS_PULL_REQUEST_SHA'] || ENV['CIRCLE_BRANCH']
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
        $stderr.puts message if @user_options["verbose"]
      end

      def error(message, help: false)
        @errors << [ message, help ]
      end

    end
  end
end