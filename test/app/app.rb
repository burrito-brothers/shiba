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


database_yml = File.join(File.dirname(__FILE__), "..", "database.yml")
database_yml = database_yml + ".example" unless File.exist?(database_yml)

connection = YAML.load_file(database_yml)

TEST_ENV = ENV['SHIBA_TEST_ENV'] || 'test'
ActiveRecord::Base.establish_connection(connection[TEST_ENV])

org = Organization.create!(name: 'test')
org.users.create!(email: 'squirrel@example.com')

user = User.find_by(email: 'squirrel@example.com') # bumpity
10.times do |i|
  user.comments.create!(body: "text #{i}")
end
