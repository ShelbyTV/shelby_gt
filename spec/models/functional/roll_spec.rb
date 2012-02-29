require 'spec_helper'

describe Roll do
  before(:each) do
    @roll = Roll.new
  end
  
  it "should have an index on [creator_id]" do
    indexes = Roll.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"a"=>1})
  end
  
  it "should abbreviate creator_id as a" do
    Roll.keys["creator_id"].abbr.should == :a
  end
  
end
