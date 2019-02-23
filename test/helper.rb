require 'bundler/setup'
require "minitest/autorun"
require "minitest/spec"
require "yaml"
require "shiba"

def cxspec_to_psql_options(cxspec)
  cmdmap = {
    'username' => 'username',
    'host' => 'host',
    'port' => 'port'
  }

  ENV['PGPASSWORD'] = cxspec['password']
  cmdmap.map do |opt, cmd|
    "--#{cmd}='#{cxspec[opt]}'" if cxspec[opt]
  end.compact.join(' ')
end

def create_test_database(cxspec)
  database = cxspec['database']
  server_type = cxspec['server']

  if server_type == "mysql"
    structure_sql = File.join(File.dirname(__FILE__), "structure.sql")
    system("mysql -e 'drop database if exists #{database}'")
    system("mysql -e 'create database #{database}'")
    system("mysql #{database} < #{structure_sql}")
  else
    structure_sql = File.join(File.dirname(__FILE__), "structure_postgres.sql")
    args = cxspec_to_psql_options(cxspec)
    # Creates 'postgres' user without super priv if it doesn't exist
    result = system("psql -c 'CREATE ROLE postgres NOSUPERUSER CREATEDB NOCREATEROLE NOINHERIT LOGIN;'")
    system("psql -c 'drop database #{database}'")
    system("psql -c 'create database #{database}'")
    system("psql #{args} #{database} < #{structure_sql}")
  end
end

database_yml = File.join(File.dirname(__FILE__), "database.yml")
database_yml = database_yml + ".example" unless File.exist?(database_yml)

connection = YAML.load_file(database_yml)

TEST_ENV = ENV['SHIBA_TEST_ENV'] || 'test'
Shiba.configure(connection[TEST_ENV])
create_test_database(connection[TEST_ENV])
