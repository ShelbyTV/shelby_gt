require 'spec_helper'

describe Conversation do
  before(:each) do
    @conversation = Conversation.new
  end
  
  it "should have an index on [video_id]" do
    indexes = Conversation.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"a"=>1})
  end
  
  it "should abbreviate video_id as :a" do
    Conversation.keys["video_id"].abbr.should == :a
  end
  
end
