require_relative 'helper'

require 'shiba'
require 'shiba/explain'
require 'shiba/explain/postgres_explain_index_conditions'
require 'shiba/table_stats'

describe "Explain" do
  def self.it_includes_tag(tag)
    it "includes #{tag}" do
      has_tag = explain.messages.any? { |m| m[:tag] == tag }
      assert(has_tag, "expected #{explain.messages} to include tag == #{tag}")
    end
  end

  let(:index_stats) do
    Shiba::TableStats.new({}, Shiba.connection, {})
  end

  let(:explain) do
    Shiba::Explain.new(sql, index_stats, [])
  end
  describe "with a SELECT *" do
    let(:sql) { "select * from users" }
    it_includes_tag("access_type_tablescan")
  end

  describe "with a SELECT * / limit 1" do
    let(:sql) { "select * from users limit 1" }
    it_includes_tag("limited_scan")
  end

  describe "a select that stays entirely in an index with a limit" do
    let(:sql) { "select 1 from users where organization_id = 1 limit 1" }
    it_includes_tag("limited_scan")
  end

  describe "postgres index conditions" do
    def parse_conditions(conds)
      Shiba::Explain::PostgresExplainIndexConditions.new(conds).fields
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
  end

  if Shiba.connection.mysql?
    describe "a join" do
      let(:sql) { "SELECT users.* from users INNER JOIN comments on comments.user_id = users.id" }

      it "parses" do
        ret = explain.messages
      end

      it_includes_tag("join_type_ref")
    end
  end
end

