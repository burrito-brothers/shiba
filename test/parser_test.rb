require_relative 'helper'

require 'shiba/parsers/postgres_explain_index_conditions'
require 'shiba/parsers/mysql_select_fields'

describe "Parsing" do
  describe "postgres index conditions" do
    def parse_conditions(conds)
      Shiba::Parsers::PostgresExplainIndexConditions.new(conds).fields
    end

    it "parses some index conditions" do
      assert_equal(%w(rgt), parse_conditions("(rgt > 7)"))
      assert_equal(%w(type), parse_conditions("((type)::text = 'TimeEntryActivity'::text)"))
      assert_equal(%w(type), parse_conditions("(((type)::text = ANY ('{Group,GroupBuiltin,GroupAnonymous,GroupNonMember}'::text[])) AND ((type)::text = 'Group'::text))"))
      assert_equal(%w(type), parse_conditions("((type)::text = 'TimeEntryActivity '' '::text)"))
      assert_equal(%w(type), parse_conditions("((type)::text = 'TimeEntryActivity '' '::text)"))
      assert_equal(%w(role_id tracker_id old_status_id), parse_conditions("((role_id = 1) AND (tracker_id = 2) AND (old_status_id = 1))"))
      assert_equal(["odd column_name"], parse_conditions("(\"odd column_name\" = 123)"))
    end

    it "parses functions on the left-hand-side" do
      assert_equal([nil], parse_conditions("(lower((name)::text) = 'application_secret'::text)"))
    end
  end

  describe "mysql select fields" do
    def parse_sql(query)
      Shiba::Parsers::MysqlSelectFields.new(query).parse_fields
    end

    it "parses normalized SQL" do
      ret = parse_sql("/* select 1 */ select `foo`.`bar` AS `foobar` from `foo`")
      assert_equal({ "foo" => ["bar"]}, ret)
    end

    it "handles collation strings" do
      ret = parse_sql("/* select#1 */ select (`tbl`.`name` collate utf8_tolower_ci) AS `TABLE_NAME` from `mysql`.`tables`")
    end
  end
end

