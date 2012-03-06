require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Frame do
  before(:each) do
    @frame = Frame.new
    @voter1 = User.new
    @voter2 = User.new
  end
  
  context "database" do

    it "should have an index on [roll_id, score]" do
      indexes = Frame.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1, "e"=>-1})
    end
  
    it "should abbreviate roll_id as :a, rank as :e" do
      Frame.keys["roll_id"].abbr.should == :a
      Frame.keys["score"].abbr.should == :e
    end
  
  end
  
  context "upvoting" do
    
    it "should have a baseline score > 0 after validation" do
      @frame.valid?.should == true
      @frame.score.should > 0
    end
  
    it "should update score with each new upvote" do
      @frame.upvote(@voter1)
      score = @frame.score
      @frame.upvote(@voter2)
      @frame.score.should > score
    end
  
    it "should add upvoting user to upvoters array" do
      @frame.has_voted?(@voter1).should == false
      @frame.upvote(@voter1)
      @frame.has_voted?(@voter1).should == true
    end
  
    it "should not allow user to upvote more than once" do
      @frame.upvote(@voter1).should == true
      score = @frame.score
      @frame.upvote(@voter1).should == false
      @frame.score.should == score
    end
  
  end
  
end
