require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Frame do
  
  context "database" do
    it "should have an identity map" do
      f = Frame.new
      f.save
      Frame.identity_map.size.should > 0
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
  
  # We're testing a private method here, but it's a pretty fucking important/tricky one and has to be correct
  context "ancestor search" do
    it "should find an ancestor when one exists" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))
      
      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :roll => @r2, :frame_ancestors => [@orig.id])
      
      Frame.send(:roll_includes_ancestor_of_frame?, @r2.id, @orig.id, 24.hours.ago).should == true
    end
    
    it "should not find an ancestor if one doesn't exist" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))
      
      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :roll => @r2, :frame_ancestors => [])
      
      Frame.send(:roll_includes_ancestor_of_frame?, @r2.id, @orig.id, 24.hours.ago).should == false
    end
    
    it "should not find an ancestor if it's too old" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))
      
      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :_id => BSON::ObjectId.from_time(2.days.ago), :roll => @r2, :frame_ancestors => [@orig.id])
      
      Frame.send(:roll_includes_ancestor_of_frame?, @r2.id, @orig.id, 24.hours.ago).should == false
      Frame.send(:roll_includes_ancestor_of_frame?, @r2.id, @orig.id, 3.days.ago).should == true
    end
    
    it "should find an ancestor after duped via Framer" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))
      
      @orig = Factory.create(:frame, :roll => @r1)

      @u = Factory.create(:user)
      @u.viewed_roll = Factory.create(:roll, :creator => @u)
      @u.save
      
      #should NOT find it now
      Frame.send(:roll_includes_ancestor_of_frame?, @u.viewed_roll_id, @orig.id, 24.hours.ago).should == false
      
      #dupe it
      GT::Framer.dupe_frame!(@orig, @u.id, @u.viewed_roll_id)
      
      #should find it now
      Frame.send(:roll_includes_ancestor_of_frame?, @u.viewed_roll_id, @orig.id, 24.hours.ago).should == true
    end
  end
  
  # We're testing a private method here, but it's a pretty fucking important/tricky one and has to be correct
  context "get ancestor" do
    it "should return an ancestor when one exists" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))
      
      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :roll => @r2, :frame_ancestors => [@orig.id])
      
      Frame.send(:get_ancestor_of_frame, @r2.id, @orig.id).should == @child
    end
    
    it "should not find an ancestor if one doesn't exist" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))
      
      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :roll => @r2, :frame_ancestors => [])
      
      Frame.send(:get_ancestor_of_frame, @r2.id, @orig.id).should == nil
    end
    
    it "should find an ancestor after duped via Framer" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))
      
      @orig = Factory.create(:frame, :roll => @r1)

      @u = Factory.create(:user)
      @u.viewed_roll = Factory.create(:roll, :creator => @u)
      @u.save
      
      #should NOT find it now
      Frame.send(:get_ancestor_of_frame, @u.viewed_roll_id, @orig.id).should ==  nil
      
      #dupe it
      child = GT::Framer.dupe_frame!(@orig, @u.id, @u.viewed_roll_id)
      
      #should find it now
      Frame.send(:get_ancestor_of_frame, @u.viewed_roll_id, @orig.id).should == child
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
  
  context "upvote undo" do
    before(:each) do
      @frame = Factory.create(:frame)
      @voter1 = Factory.create(:user)
      @voter1.upvoted_roll = Factory.create(:roll, :creator => @voter1)
      @voter1.save

      @voter2 = Factory.create(:user)
      @voter2.upvoted_roll = Factory.create(:roll, :creator => @voter2)
      @voter2.save
      
      @frame.upvote!(@voter1)
      @frame.upvote!(@voter2)
    end
    
    it "should decrease score with each new upvote_undo" do
        score_before = @frame.score
        @frame.upvote_undo!(@voter1)
        @frame.score.should < score_before
    end
    
    it "should remove upvoting user from upvoters array and remove dupe of self from user.upvoted_roll" do
      lambda {
        @voter1.upvoted_roll.frames.count.should == 1
        @frame.upvoters.should include(@voter1.id)
        
        @frame.upvote_undo!(@voter1)
        @frame.upvoters.should_not include(@voter1.id)
        @frame.upvoters.should include(@voter2.id)
        
        @voter1.upvoted_roll.frames.count.should == 0
      }.should change { @frame.upvoters.count } .by(-1)
    end
    
    it "should not allow user to upvote_undo more than once" do
      @frame.upvote_undo!(@voter1).should == true
      score = @frame.score
      @frame.upvote_undo!(@voter1).should == false
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

      f.creator_id.should == @frame.creator_id
      f.video_id.should == @frame.video_id
      f.conversation_id.should == @frame.conversation_id
      f.frame_ancestors.include?(@frame.id).should == true
    end
    
    it "should be idempotent" do
      f1, f2 = nil, nil
      lambda {
        f1 = @frame.add_to_watch_later!(@u1)
        f2 = @frame.add_to_watch_later!(@u1)
      }.should change { Frame.count } .by 1
      
      f1.should == f2
    end
  end
  
  context "viewed" do
    before(:each) do
      @frame = Factory.create(:frame)
      @frame.video = Factory.create(:video)
      @frame.save
      
      @u1 = Factory.create(:user)
      @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
      @u1.save
    end
    
    it "should require full User model, not just id" do
      lambda {
        @frame.view!(@u1.id)
      }.should raise_error(ArgumentError)
    end
    
    it "should dupe the frame into the users viewed_roll, persisted" do
      f = nil
      lambda {
        f = @frame.view!(@u1)
      }.should change { Frame.count } .by 1

      f.persisted?.should == true      
      f.roll.should == @u1.viewed_roll
    end
    
    it "should set metadata correctly" do
      f = nil
      lambda {
        f = @frame.view!(@u1)
      }.should change { Frame.count } .by 1

      f.creator_id.should == @frame.creator_id
      f.video_id.should == @frame.video_id
      f.conversation_id.should == @frame.conversation_id
      f.frame_ancestors.include?(@frame.id).should == true
    end
    
    it "should update view_count of Frame" do
      lambda {
        @frame.view!(@u1)
      }.should change { @frame.reload.view_count } .by 1
      
      lambda {
        Frame.should_receive(:roll_includes_ancestor_of_frame?).exactly(4).times.and_return(false)
        @frame.view!(@u1)
        @frame.view!(@u1)
        @frame.view!(@u1)
        @frame.view!(@u1)
      }.should change { @frame.reload.view_count } .by 4
    end
    
    it "should update view_count of Frame's Video" do
      lambda {
        @frame.view!(@u1)
      }.should change { @frame.video.reload.view_count } .by 1
      
      lambda {
        Frame.should_receive(:roll_includes_ancestor_of_frame?).exactly(4).times.and_return(false)
        @frame.view!(@u1)
        @frame.view!(@u1)
        @frame.view!(@u1)
        @frame.view!(@u1)
      }.should change { @frame.video.reload.view_count } .by 4
    end
  end
  
  context "destroy" do
    before(:each) do
      @creator = Factory.create(:user)
      @frame = Factory.create(:frame, :creator => @creator)
      @stranger = Factory.create(:user)
    end
    
    it "should allow destroy if destroyer is creator" do
      @frame.destroyable_by?(@creator).should == true
      @frame.destroyable_by?(@stranger).should == false
    end
    
    it "should allow destory if creator is nil" do
      @frame.creator = nil
      @frame.save
      @frame.destroyable_by?(@creator).should == true
      @frame.destroyable_by?(@stranger).should == true
    end
    
    it "should allow destroy if destroyer is roll creator" do
      roll = Factory.create(:roll, :creator => @stranger)
      @frame.roll = roll
      @frame.save
      @frame.destroyable_by?(@stranger).should == true
    end
    
  end
  
end
