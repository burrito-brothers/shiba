#!/usr/bin/env ruby

require 'optionparser'
require 'shiba/configure'

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "watch <command>. Create SQL logs for a running process"

  opts.on("-h","--host HOST", "sql host") do |h|
    options["host"] = h
  end

  opts.on("-d","--database DATABASE", "sql database") do |d|
    options["database"] = d
  end

  opts.on("-u","--user USER", "sql user") do |u|
    options["user"] = u
  end

  opts.on("-p","--password PASSWORD", "sql password") do |p|
    options["password"] = p
  end

end

# Automagic configuration goes here
if !options["database"]
    config = Shiba::Configure.activerecord_configuration
  
    if tc = config && config['test']
      $stderr.puts "Reading configuration from '#{`pwd`.chomp}/config/database.yml'[:test]."
      options['host']     ||= tc['hostname']
      options['database'] ||= tc['database']
      options['user'] ||= tc['username']
      options['password'] ||= tc['password']
    end
  end
  
  if !options["file"]
    options["file"] = `mktemp /tmp/shiba-analyze.log-#{Time.now.to_i}`.chomp
  end

parser.parse!

$stderr.puts "Recording SQL queries..."
pid = fork do
    trap('INT') { exit }
    ENV['SHIBA_OUT'] = options["file"]
    Kernel.exec(ARGV.join(" "))
end

Process.wait(pid)

$stderr.puts "Analyzing SQL..."
path = "#{File.dirname(__FILE__)}/analyze.rb"

args = options.select { |_,v| !v.nil? }.map { |k,v| [ "--#{k}", v ] }.flatten

Kernel.exec(path, *args)