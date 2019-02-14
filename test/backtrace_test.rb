require 'helper'
require 'shiba/backtrace'


describe "Backtrace" do

  it "doesn't blow up" do
    Shiba::Backtrace.from_app
  end

end