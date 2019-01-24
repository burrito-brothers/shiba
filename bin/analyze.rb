#!/usr/bin/env ruby

require 'bundler/setup'
require 'shiba'
require 'shiba/cli'
require 'optionparser'

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: analyze.rb --host=HOST --database=DB --user=USER --password=PASS"

  opts.on("-h","--host HOST") do |h|
    options["host"] = h
  end

  opts.on("-d","--database DATABASE") do |d|
    options["database"] = d
  end

  opts.on("-u","--user USER") do |u|
    options["username"] = u
  end

  opts.on("-p","--password PASSWORD") do |p|
    options["password"] = p
  end
end
parser.parse!

["host", "database", "username", "password"].each do |opt|
  if !options[opt]
    puts parser.banner
    exit
  end
end

Shiba.configure(options)
Shiba::Cli.analyze
