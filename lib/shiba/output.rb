require 'yaml'
require 'json'
require 'fileutils'
require 'erb'

module Shiba
  class Output

    OUTPUT_PATH = "/tmp/shiba_results"
    JS_PATH = OUTPUT_PATH + "/js"

    WEB_PATH = File.dirname(__FILE__) + "/../../web"
    def self.tags
      @tags ||= YAML.load_file(File.dirname(__FILE__) + "/output/tags.yaml")
    end

    def self.from_file(fname)
      queries = []
      File.open(fname, "r") do |f|
        while line = f.gets
          queries << JSON.parse(line)
        end
      end
      new(queries)
    end


    def initialize(queries)
      @queries = queries
    end

    def make_web!
      FileUtils.mkdir_p(JS_PATH)

      js = Dir.glob(WEB_PATH + "/dist/*.js").map { |f| File.basename(f) }
      js.each do |f|
        system("cp #{WEB_PATH}/dist/#{f} #{JS_PATH}")
      end

      data = {
        js: js,
        queries: @queries,
        tags: self.class.tags
      }

      system("cp #{WEB_PATH}/*.css #{OUTPUT_PATH}")


      erb = ERB.new(File.read(WEB_PATH + "/../web/results.html.erb"))
      File.open(OUTPUT_PATH + "/results.html", "w+") do |f|
        f.write(erb.result(binding))
      end

      puts "done, results are in " + "/tmp/shiba_results/results.html"
    end
  end
end
