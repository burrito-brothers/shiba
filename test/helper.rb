require 'bundler/setup'
require "minitest/autorun"
require "minitest/spec"


def create_test_database
  structure_sql = File.join(File.dirname(__FILE__), "structure.sql")
  system("mysql -e 'drop database if exists shiba_test'")
  system("mysql -e 'create database shiba_test'")
  system("mysql shiba_test < #{structure_sql}")
end

create_test_database
