require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Frame do
  before(:each) do
    @frame = Frame.new
  end
  
  it "should have an index on [roll_id, score]" do
    indexes = Frame.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"a"=>1, "e"=>-1})
  end
  
  it "should abbreviate roll_id as :a, rank as :e" do
    Frame.keys["roll_id"].abbr.should == :a
    Frame.keys["score"].abbr.should == :e
  end
  
end
