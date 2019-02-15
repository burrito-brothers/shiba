require 'bundler'
Bundler.setup(:test)
require 'active_record'
require 'shiba'
require 'shiba/backtrace'
Shiba::Backtrace.ignore.delete('test')


require_relative './models/organization'
require_relative './models/user'

if ENV['SHIBA_DEBUG']
  ActiveRecord::Base.logger = Logger.new('/dev/stdout')
end
ActiveRecord::Base.establish_connection('adapter' => 'mysql2', 'database' => 'shiba_test', 'username' => 'root')

org = Organization.create!(name: 'test')
org.users.create!(email: 'squirrel@example.com')

User.find_by(email: 'squirrel@example.com')