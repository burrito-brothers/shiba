require_relative 'helper'

require 'shiba'
require 'shiba/explain'
require 'shiba/table_stats'

describe "Explain" do
  before do
    Shiba.configure('database' => 'shiba_test', 'default_file' => '~/.my.cnf', 'default_group' => 'client', 'server' => 'mysql')
  end

  let(:index_stats) do
    Shiba::TableStats.new({}, Shiba.connection, {})
  end

  let(:explain) do
    Shiba::Explain.new(sql, index_stats, [])
  end

  def self.it_includes_tag(tag)
    it "includes #{tag}" do
      assert_includes(explain.messages, tag)
    end
  end

  describe "with a SELECT *" do
    let(:sql) { "select * from users" }
    it_includes_tag("access_type_tablescan")
  end

  describe "with a SELECT * / limit 1" do
    let(:sql) { "select * from users limit 1" }
    it "tags as limited_scan" do
      assert_includes(explain.messages, "limited_scan")
    end
  end

  describe "a select that stays entirely in an index with a limit" do
    let(:sql) { "select 1 from users where organization_id = 1 limit 1" }
    it "tags as limited_scan" do
      assert_includes(explain.messages, "limited_scan")
    end
  end
end
