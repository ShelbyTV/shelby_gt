require 'spec_helper'

#Functional: hit the database, treat model as black box
describe UserAction do
  before(:each) do
    
  end
  
  context "database" do
    
    it "should have an index on [user_id, type]" do
      indexes = UserAction.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"b"=>1, "a" => 1})
    end
  
    it "should abbreviate type as :a" do
      UserAction.keys["type"].abbr.should == :a
    end
  
    it "should abbreviate user_id as :b" do
      UserAction.keys["user_id"].abbr.should == :b
    end
    
    it "should abbreviate frame_id as :a" do
      UserAction.keys["frame_id"].abbr.should == :c
    end
      
  end
  
end
