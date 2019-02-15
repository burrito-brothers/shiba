require 'helper'
require 'shiba'
require 'shiba/fuzzer'

describe "Connection" do

  it "doesn't blow up" do
    Shiba.configure('database' => 'shiba_test', 'default_file' => '~/.my.cnf', 'default_group' => 'client')
    assert_equal 'shiba_test', Shiba.connection.query("select database() as db").first["db"]

    stats = Shiba::Fuzzer.new(Shiba.connection).fuzz!
    assert stats.any?, stats.inspect
  end

end