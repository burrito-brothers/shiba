require_relative 'helper'

require 'shiba/fuzzer'

describe "Dumping" do
  describe "tables without indexes" do
    before do
      Shiba.connection.query("create table no_index ( i int )")
    end

    after do
      Shiba.connection.query("drop table if exists no_index")
    end

    let(:fuzzer) { Shiba::Fuzzer.new(Shiba.connection) }
    it "doesn't crash the fuzzer" do
      fuzzer.fetch_index
    end
  end
end

