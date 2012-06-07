require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Conversation do
  before(:each) do
    @conversation = Conversation.new
  end
  
  context "database" do

    it "should have an identity map" do
      c = Conversation.new
      m = Message.new
      m.origin_id = rand.to_s
      c.save
      Conversation.identity_map.size.should > 0
    end
    
    it "should have an index on [video_id]" do
      indexes = Conversation.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1})
      indexes.should include({"messages.b"=>1})
    end
  
    it "should abbreviate video_id as :a" do
      Conversation.keys["video_id"].abbr.should == :a
    end
    
    it "should have message after pulling from DB" do
      c = Conversation.new
      m = Message.new
      m.origin_id = rand.to_s
      c.messages << m
      lambda {
        c.save.should == true
      }.should change {Conversation.count}.by(1)
      c.persisted?.should == true
      c.messages[0].persisted?.should == true
      
      Conversation.all[0].is_a?(Conversation).should == true
      
      c2 = Conversation.find(c.id)
      c2.messages.size.should == 1
      c2.messages[0].origin_id.should == m.origin_id
    end
    
    it "should be findable by message.origin_id" do
      c = Conversation.new
      m = Message.new
      m.origin_id = rand.to_s
      c.messages << m
      c.save.should == true
      c.persisted?.should == true
      
      Conversation.first_including_message_origin_id(m.origin_id).should == c
    end
  
  end
  
end
