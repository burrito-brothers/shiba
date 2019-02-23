require 'uri'
require 'json'
require 'net/http'

module Shiba
  module Review
    class API

      attr_reader :repo_url, :token, :pull_request

      # options "token", "pull_request"
      def initialize(repo_url, options)
        @repo_url = repo_url
        @http = nil
        @token = options.fetch("token")
        @pull_request = options.fetch("pull_request")
      end

      def connect
        Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
          begin
            @http = http
            yield
          ensure
            @http = nil
          end
        end
      end

      # https://developer.github.com/v3/pulls/comments/#create-a-comment
      def comment_on_pull_request(comment)
        req = Net::HTTP::Post.new(uri)
        req.body = JSON.dump(comment)
        request(req)
      end

      # https://developer.github.com/v3/pulls/comments/#list-comments-on-a-pull-request
      def previous_comments
        req = Net::HTTP::Get.new(uri)
        request(req)
      end

      def uri
        return @uri if @uri

        repo_host, repo_path = host_and_path
        url = if repo_host == 'github.com'
          'https://api.github.com'
        else
          "https://#{repo_host}/api/v3"
        end
        url << "/repos/#{repo_path}/pulls/#{pull_request}/comments"

        @uri = URI(url)
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

      protected

      def request(req)
        verify_connection!

        req['Authorization'] = "token #{token}"
        req['Content-Type']  = "application/json"

        res = @http.request(req)

        case res
        when Net::HTTPSuccess
          JSON.parse(res.body)
        else
          raise Shiba::Error.new, "API request failed: #{res} #{res.body}"
        end
      end

      def verify_connection!
        return true if @http
        raise Shiba::Error.new("API requests must be wrapped in a #connect { ... } block")
      end

    end
  end
end