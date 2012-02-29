require 'spec_helper'

describe Roll do
  before(:each) do
    @roll = Roll.new
  end
  
  it "should have an index on [creator_id]" do
    indexes = Roll.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"creator_id"=>1})
  end
  
end
