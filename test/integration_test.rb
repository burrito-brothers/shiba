require 'helper'
require 'shiba'

describe "Connection" do

  it "doesn't blow up" do
    Shiba.configure(database: 'shiba_test', 'default_file' => '~/.my.cnf', 'default_group' => 'client')
    assert Shiba.connection.query('select 1')
  end

end