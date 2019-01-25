require "shiba/version"
require "mysql2"

module Shiba
  class Error < StandardError; end

  def self.configure(connection_hash)
    @connection_hash = connection_hash
  end

  def self.connection
    @connection ||= Mysql2::Client.new(@connection_hash)
  end

  def self.root
    File.dirname(__dir__)
  end
end
