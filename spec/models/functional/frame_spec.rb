require 'spec_helper'

describe Frame do
  before(:each) do
    @frame = Frame.new
  end
  
  it "should have an index on [roll_id, rank]" do
    indexes = Frame.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"roll_id"=>1, "score"=>-1})
  end
  
end
