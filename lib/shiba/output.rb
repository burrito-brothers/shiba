require 'yaml'
require 'json'
require 'fileutils'
require 'tmpdir'
require 'erb'

module Shiba
  class Output
    WEB_PATH = File.join(File.dirname(__FILE__), "..", "..", "web")
    def self.tags
      @tags ||= YAML.load_file(File.join(File.dirname(__FILE__), "output", "tags.yaml"))
    end

    def initialize(queries, options = {})
      @queries = queries
      @options = options
    end

    def default_filename
      @default_filename ||= "shiba_results-#{Time.now.to_i}.html"
    end

    def logdir
      File.join(Dir.pwd, "log")
    end

    def output_path
      return @options['output'] if @options['output']
      if File.exist?(logdir)
        FileUtils.mkdir_p(File.join(logdir, "shiba_results"))
        File.join(Dir.pwd, "log", "shiba_results", default_filename)
      else
        File.join(Shiba.path, default_filename)
      end
    end

    def js_path
      File.join(output_path, "js")
    end

    def remote_url
      url = `git config --get remote.origin.url` rescue nil
      return nil unless url
      return nil if url =~ %r{burrito-brothers/shiba}
      url.chomp!
      url.gsub!('git@github.com:', 'https://github.com/')
      url.gsub!(/\.git$/, '')

      branch = `git symbolic-ref HEAD`.strip.split('/').last
      url + "/blob/#{branch}"
    end

    def as_json
      js  = Dir.glob(File.join(WEB_PATH, "dist", "*.js"))
      css = Dir.glob(File.join(WEB_PATH, "*.css"))

      {
        js: js,
        css: css,
        queries: @queries,
        tags: self.class.tags,
        url: remote_url
      }
    end

    def make_web!
      data = as_json

      erb = ERB.new(File.read(File.join(WEB_PATH, "..", "web", "results.html.erb")))
      File.open(output_path, "w+") do |f|
        f.write(erb.result(binding))
      end

      output_path
    end
  end
end
