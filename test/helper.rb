require 'bundler/setup'
require "minitest/autorun"
require "minitest/spec"
require "yaml"
require "shiba"


def create_test_database(database)
  structure_sql = File.join(File.dirname(__FILE__), "structure.sql")
  system("mysql -e 'drop database if exists #{database}'")
  system("mysql -e 'create database #{database}'")
  system("mysql #{database} < #{structure_sql}")
end

database_yml = File.join(File.dirname(__FILE__), "database.yml")
database_yml = database_yml + ".example" unless File.exist?(database_yml)

connection = YAML.load_file(database_yml)

Shiba.configure(connection['mysql'].merge('server' => 'mysql'))
create_test_database(connection['mysql']['database'])
