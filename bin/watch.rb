#!/usr/bin/env ruby

require 'optionparser'

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "watch <command>. Create SQL logs for a running process"

  opts.on("-f", "--file FILE", "write to file") do |f|
    options["file"] = f
  end

end

parser.parse!

$stderr.puts "Recording SQL queries to '#{options["file"]}'..."
ENV['SHIBA_OUT'] = options["file"]
Kernel.exec(ARGV.join(" "))