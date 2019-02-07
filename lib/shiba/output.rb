require 'yaml'
require 'json'
require 'fileutils'
require 'erb'

module Shiba
  class Output
    OUTPUT_PATH = "/tmp/shiba_results"

    WEB_PATH = File.dirname(__FILE__) + "/../../web"
    def self.tags
      @tags ||= YAML.load_file(File.dirname(__FILE__) + "/output/tags.yaml")
    end

    def initialize(queries, options = {})
      @queries = queries
      @options = options
    end

    def output_path
      path ||= File.join(@options['output'], "shiba_results") if @options['output']
      path ||= Dir.pwd + "/log/shiba_results" if File.exist?(Dir.pwd + "/log")
      path ||= OUTPUT_PATH
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
      url + '/blob/master/'
    end

    def make_web!
      js  = Dir.glob(WEB_PATH + "/dist/*.js")
      css = Dir.glob(WEB_PATH + "/*.css")

      data = {
        js: js,
        css: css,
        queries: @queries,
        tags: self.class.tags,
        url: remote_url
      }

      system("cp #{WEB_PATH}/*.css #{output_path}")

      erb = ERB.new(File.read(WEB_PATH + "/../web/results.html.erb"))
      File.open(output_path + "/results.html", "w+") do |f|
        f.write(erb.result(binding))
      end


      "#{output_path}/results.html"
    end
  end
end
