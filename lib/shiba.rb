require "shiba/version"
require "shiba/configure"
require "shiba/connection"
require "mysql2"
require "pp"
require "byebug" if ENV['SHIBA_DEBUG']

module Shiba
  class Error < StandardError; end

  def self.configure(options)
    @connection_hash = options.select { |k, v| [ 'default_file', 'default_group', 'server', 'username', 'database', 'host', 'password', 'port'].include?(k) }
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
    return @connection if @connection
    @connection = Shiba::Connection.build(@connection_hash)
  end

  def self.database
    @connection_hash['database']
  end

  def self.root
    File.dirname(__dir__)
  end

  def self.path
    @log_path ||= ENV['SHIBA_PATH'] || try_tmp || use_tmpdir
  end

  private

  def self.try_tmp
    return if !Dir.exist?('/tmp')
    return if !File.writable?('/tmp')

    path = File.join('/tmp', 'shiba')
    Dir.mkdir(path) if !Dir.exist?(path)
    path
  end

  def self.use_tmpdir
    path = File.join(Dir.tmpdir, 'shiba')
    Dir.mkdir(path) if !Dir.exist?(path)
    path
  end
end

# This goes at the end so that Shiba.root is defined.
if defined?(ActiveSupport.on_load)
  require 'shiba/activerecord_integration'
  Shiba::ActiveRecordIntegration.install!
end
