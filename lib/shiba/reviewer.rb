require 'uri'
require 'json'
require 'open3'
require 'yaml'
require 'shiba'
require 'shiba/diff'

module Shiba
  class Reviewer
    TEMPLATE_FILE = File.join(Shiba.root, 'lib/shiba/output/tags.yaml')

    attr_reader :repo_url, :problems, :options

    def initialize(repo_url, problems, options)
      @repo_url = repo_url
      @problems = problems
      @options = options
    end

    def comments
      return @comments if @comments

      cmd ="git diff origin/HEAD..#{options[:branch]}"
      if options[:verbose]
        puts "Finding PR position using: #{cmd}"
      end
      output = StringIO.new(`#{cmd}`)
      diff = Shiba::Diff.new(output)

      @comments = problems.map do |path, explain|
        file, line_number = path.split(":")
        if path.empty? || line_number.nil?
          raise StandardError.new("Bad path received: ", line_number)
        end

        position = diff.find_position(file, line_number.to_i)

        { body: renderer.render(explain),
          commit_id: options["branch"],
          path: file,
          line: line_number,
          position: position }
      end
    end

    # POST
    # https://developer.github.com/v3/pulls/comments/#create-a-comment
    # enterprise | normal
    # https://[YOUR_HOST]/api/v3 | https://api.github.com

    #body	string	Required. The text of the comment.
    #commit_id	string	Required. The SHA of the commit needing a comment. Not using the latest commit SHA may render your comment outdated if a subsequent commit modifies the line you specify as the position.
    #path	string	Required. The relative path to the file that necessitates a comment.
    #position	integer	Required. The position in the diff where you want to add a review comment. Note this value is not the same as the line number in the file. For help finding the position value, read the note below.


    #curl -i -H "Authorization: token #{token}" \
    #    -H "Content-Type: application/json" \
    #    -X POST -d "{\"body\":\"$ASPELL_RESULTS\"}" \
    #    url
    def post_comments
      puts "Posting to #{api_url}"
    end

    def repo_host
      @repo_host ||= host_and_path.first
    end

    def repo_path
      @repo_path ||= host_and_path.last
    end

    protected

    def renderer
      @renderer ||= CommentRenderer.new(TEMPLATE_FILE)
    end

    def api_url
      return @url if @url

      @url = if repo_host == 'github.com'
        'https://api.github.com'
      else
        "https://#{repo_host}/api/v3"
      end
      @url << "/repos/#{repo_path}/pulls/#{options["pull_request"]}/comments"

      @url
    end

    def host_and_path
       host, path = nil
       # git@github.com:burrito-brothers/shiba.git
       if repo_url.index('@')
         host, path = repo_url.split(':')
         host.sub!('git@', '')
         path.chomp!('.git')
       # https://github.com/burrito-brothers/shiba.git
       else
         uri = URI.parse(repo_url)
         host = uri.host
         path = uri.path.chomp('.git')
         path.reverse!.chomp!("/").reverse!
       end

       return host, path
    end
  end

  class CommentRenderer
    # {{ variable }}
    VAR_PATTERN = /{{\s?([a-z_]+)\s?}}/

    def initialize(file)
      @file = file
    end

    def render(explain)
      body = ""
      data = present(explain)
      explain["tags"].each do |tag|
        body << templates[tag]["title"]
        body << ": "
        body << render_template(templates[tag]["summary"], data)
        body << "\n"
      end

      body
    end

    protected

    def render_template(template, data)
      rendered = template.gsub(VAR_PATTERN) do
        data[$1]
      end
      # convert to markdown
      rendered.gsub!(/<\/?b>/, "**")
      rendered
    end

    def present(explain)
      used_key_parts = explain["used_key_parts"] || []

      { "table"       => explain["table"],
        "table_size"  => explain["table_size"],
        "key"         => explain["key"],
        "return_size" => explain["return_size"],
        "key_parts"   => used_key_parts.join(","),
        "cost"        => cost(explain)
      }
    end

    def cost(explain)
      percentage = (explain["cost"] / explain["table_size"]) * 100.0;

      if explain["cost"] > 100 && percentage > 1
        "#{percentage.floor}% (#{explain["cost"]}) of the"
      else
        explain["cost"]
      end
    end


    def templates
      @templates ||= YAML.load_file(@file)
    end
  end
end