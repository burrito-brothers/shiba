require_relative 'helper'

require 'shiba'
require 'shiba/explain'
require 'shiba/query'
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

  let(:query) do
    Shiba::Query.new(sql, index_stats)
  end

  let(:explain) { query.explain }

  describe "with a SELECT *" do
    let(:sql) { "select * from users" }
    it_includes_tag("access_type_tablescan")
  end

  describe "a table scan on a small table" do
    let(:sql) { "select * from organizations" }
    it "should report as at least 10ms" do
      assert_operator(0.010, :<=, explain.cost)
    end
  end

  describe "with a SELECT * / limit 1" do
    let(:sql) { "select * from users limit 1" }
    it_includes_tag("limited_scan")
  end

  describe "a select that stays entirely in an index with a limit" do
    let(:sql) { "select 1 from users where organization_id = 1 limit 1" }
    it_includes_tag("limited_scan")
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

  describe "a select on a table without indexes" do
    before do
      Shiba.connection.query("create table no_index ( i int )")
    end

    after do
      Shiba.connection.query("drop table if exists no_index")
    end

    let(:sql) { "select * from no_index " }
    it "doesn't crash" do
      ret = explain.messages
      puts ret
    end
  end
end

