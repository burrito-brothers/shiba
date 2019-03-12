require 'bundler'
Bundler.setup(:test)
require 'shiba'
require 'shiba/backtrace'
Shiba::Backtrace.ignore.delete('test')
require 'active_record'
require 'shiba/setup'

require_relative './models/organization'
require_relative './models/user'
require_relative './models/comment'

if ENV['SHIBA_DEBUG']
  ActiveRecord::Base.logger = Logger.new('/dev/stdout')
end

# VERY CAREFUL CHANGING THE LINES OF THIS FILE.  THE TEST WILL BREAK IF YOU ADD LINES
database_yml = File.join(File.dirname(__FILE__), "..", "database.yml")
database_yml = database_yml + ".example" unless File.exist?(database_yml)

connection = YAML.load_file(database_yml)

test_env = ENV['SHIBA_TEST_ENV'] || 'test'
test_env = "test_#{test_env}" unless test_env.start_with?("test")
ActiveRecord::Base.establish_connection(connection[test_env])

org = Organization.create!(name: 'test')
org.users.create!(email: 'squirrel@example.com')
users = User.where(email: 'squirrel@example.com').to_a # bumpity
user  = User.first
10.times do |i|
  user.comments.create!(body: "text #{i}")
end
