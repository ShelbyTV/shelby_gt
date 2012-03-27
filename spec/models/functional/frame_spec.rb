require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Frame do
  
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
    before(:each) do
      @frame = Factory.create(:frame)
      @voter1 = Factory.create(:user)
      @voter1.upvoted_roll = Factory.create(:roll, :creator => @voter1)
      @voter1.save

      @voter2 = Factory.create(:user)
      @voter2.upvoted_roll = Factory.create(:roll, :creator => @voter2)
      @voter2.save
    end
    
    it "should have a baseline score > 0 after validation" do
      @frame.valid?.should == true
      @frame.score.should > 0
    end
  
    it "should require full User model on upvote, not just user_id" do
      lambda {
        @frame.upvote!(@voter1.id)
      }.should raise_error(ArgumentError)
    end
  
    it "should update score with each new upvote" do
      @frame.upvote!(@voter1)
      score = @frame.score
      @frame.upvote!(@voter2)
      @frame.score.should > score
    end
  
    it "should add upvoting user to upvoters array and dupe self into user.upvoted_roll" do
      @frame.has_voted?(@voter1).should == false
      
      lambda {
        @frame.upvote!(@voter1)
      }.should change {Frame.count} .by 1
      
      @frame.has_voted?(@voter1).should == true
    end
  
    it "should not allow user to upvote more than once" do
      @frame.upvote!(@voter1).should == true
      score = @frame.score
      @frame.upvote!(@voter1).should == false
      @frame.score.should == score
    end
  end
  
  context "watch later" do
    before(:each) do
      @frame = Factory.create(:frame)
      
      @u1 = Factory.create(:user)
      @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
    end
    
    it "should require full User model, not just id" do
      lambda {
        @frame.add_to_watch_later!(@u1.id)
      }.should raise_error(ArgumentError)
    end
    
    it "should dupe the frame into the users watch_later_roll, persisted" do
      f = nil
      lambda {
        f = @frame.add_to_watch_later!(@u1)
      }.should change { Frame.count } .by 1

      f.persisted?.should == true      
      f.roll.should == @u1.watch_later_roll
    end
    
    it "should set metadata correctly" do
      f = nil
      lambda {
        f = @frame.add_to_watch_later!(@u1)
      }.should change { Frame.count } .by 1

      f.creator_id.should == @u1.id
      f.video_id.should == @frame.video_id
      f.conversation_id.should == @frame.conversation_id
      f.frame_ancestors.include?(@frame.id).should == true
    end
  end
  
end
