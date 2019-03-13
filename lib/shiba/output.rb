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
      {
        queries: @queries,
        tags: self.class.tags,
        url: remote_url
      }
    end

    def make_web!
      data = as_json

      index_path = File.join(WEB_PATH, "dist", "index.html")
      if !File.exist?(index_path)
        raise Shiba::Error.new("dist/index.html not found. Try running 'rake build_web'")
      end
      index = File.read(index_path)
      data_block = "var shibaData = #{JSON.dump(as_json)};\n"

      index.sub!(%r{<script src=(.*?)>}) do |match|
        "<script>" + data_block + File.read(File.join(WEB_PATH, "dist", $1))
      end

      File.open(output_path, "w+") do |f|
        f.write(index)
      end

      output_path
    end
  end
end
