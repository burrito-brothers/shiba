require "shiba/version"
require "shiba/configure"
require "mysql2"
require "pp"
require "byebug" if ENV['SHIBA_DEBUG']

module Shiba
  class Error < StandardError; end

  def self.configure(options)
    @connection_hash = options.select { |k, v| [ 'default_file', 'default_group', 'username', 'database', 'host', 'password'].include?(k) }
    @main_config = Configure.read_config_file(options['config'], "config/shiba.yml")
    @index_config = Configure.read_config_file(options['index'], "config/shiba_index.yml")
  end

  def self.config
    @main_config
  end

  def self.index_config
    @index_config
  end

  def self.connection
    @connection ||= Mysql2::Client.new(@connection_hash)
  end

  def self.root
    File.dirname(__dir__)
  end
end

# This goes at the end so that Shiba.root is defined.
require "shiba/railtie" if defined?(Rails)
