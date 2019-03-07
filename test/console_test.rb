require_relative 'helper'
require 'shiba/console'

describe "Console shiba helper" do
  class FakeIRB
    include Shiba::Console

    attr_reader :messages

    def initialize
      @messages = []
    end

    def puts(message)
      @messages << message
    end
  end

  let(:console) { FakeIRB.new }

  it "explains SQL Strings" do
    explain = console.shiba("select * from users")

    assert_match /table scan/i, console.messages.first
    assert_equal 'select * from users', explain.sql
    assert explain
  end

  it "returns an error when given unsupported sql" do
    explain = console.shiba("drop table users")
    assert_nil explain
    error = /Query does not appear to be a valid relation or select sql string/
    assert_match error, console.messages.first
  end

  it "can be introspected" do
    explain = console.shiba("select * from users")
    assert !explain.help.empty?
    assert !explain.inspect.empty?
  end

  describe "on ActiveRecord/Arel style objects" do
    let(:relation) do
      Object.new.tap do |o|
        o.define_singleton_method(:to_sql) { "select * from users" }
      end
    end

    it "explains" do
      explain = console.shiba(relation)

      assert_match /table scan/i, console.messages.first
      assert_equal 'select * from users', explain.sql
    end
  end

end