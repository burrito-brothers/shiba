require_relative 'helper'

require 'shiba'
require 'shiba/explain'
require 'shiba/table_stats'

describe "Explain" do
  before do
    Shiba.configure('database' => 'shiba_test', 'default_file' => '~/.my.cnf', 'default_group' => 'client')
  end

  let(:index_stats) do
    Shiba::TableStats.new({}, Shiba.connection, {})
  end

  let(:explain) do
    Shiba::Explain.new(sql, index_stats, [])
  end

  describe "with a SELECT *" do
    let(:sql) { "select * from users" }
    it "warns about tablescans" do
      assert_includes(explain.messages, "access_type_tablescan")
    end
  end
end
