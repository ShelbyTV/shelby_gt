require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Conversation do
  before(:each) do
    @conversation = Conversation.new
  end
  
  context "database" do
    
    it "should have an index on [video_id]" do
      indexes = Conversation.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1})
      indexes.should include({"messages.b"=>1})
    end
  
    it "should abbreviate video_id as :a" do
      Conversation.keys["video_id"].abbr.should == :a
    end
  
  end
  
end
