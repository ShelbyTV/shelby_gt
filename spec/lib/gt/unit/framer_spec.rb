require 'spec_helper'
require 'framer'
require 'video_manager'

# UNIT test
# N.B. GT::Framer.re_roll is also tested by unit/frame_spec.rb
describe GT::Framer do
  
  context "creating Frames" do
    before(:each) do
      @video = Factory.create(:video, :thumbnail_url => "thum_url")
      @frame_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
      @message = Message.new
      @message.public = true
    
      @roll_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
      @roll = Roll.new( :title => "title" )
      @roll.creator = @roll_creator
      @roll.save
    end
  
    it "should create a Frame for a given Video, Message, Roll and User" do
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
    
      res[:frame].persisted?.should == true
      res[:frame].creator.should == @frame_creator
      res[:frame].video.should == @video
      res[:frame].conversation.persisted?.should == true
      res[:frame].conversation.messages.size.should == 1
      res[:frame].conversation.messages[0].should == @message
      res[:frame].conversation.messages[0].persisted?.should == true
      res[:frame].roll.should == @roll
    end
    
    it "should return false if safe save failed due to duplicate key" do
      @message.origin_id = "12345"
      lambda {
        res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :roll => @roll
          )
        res[:frame].class.should == Frame
      }.should change { Frame.count } .by(1)
        
      lambda {
        res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :roll => @roll
          )
        res.should == false
      }.should_not change { Frame.count }
    end
    
    it "should track the Frame in the Conversation" do
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
    
      res[:frame].conversation.frame.should == res[:frame]
    end
    
    it "should set the frame's roll's thumbnail_url if it's nil" do
      @roll.thumbnail_url.blank?.should == true
      
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
    
      res[:frame].roll.thumbnail_url.should == @video.thumbnail_url
    end
    
    it "should not touch the frame's roll's thumbnail_url if it's already set" do
      @roll.update_attribute(:thumbnail_url, "something://el.se")
      
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
    
      res[:frame].roll.thumbnail_url.should == "something://el.se"
    end

    it "should create no DashboardEntries if the roll has no followers" do
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
      
      res[:dashboard_entries].size.should == 0
    end
  
    it "should create a DashboardEntry for the Roll's single follower" do
      @roll.add_follower(@roll_creator)
      
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
      
      #only the rolls creator should have a DashboardEntry
      res[:dashboard_entries].size.should == 1
      res[:dashboard_entries][0].persisted?.should == true
      res[:dashboard_entries][0].reload
      res[:dashboard_entries][0].user_id.should == @roll_creator.id
      res[:dashboard_entries][0].user.should == @roll_creator
      res[:dashboard_entries][0].roll.should == @roll
      res[:dashboard_entries][0].frame.should == res[:frame]
      res[:dashboard_entries][0].read?.should == false
      res[:dashboard_entries][0].action.should == DashboardEntry::ENTRY_TYPE[:new_social_frame]
      res[:dashboard_entries][0].actor.should == nil
    end
  
    it "should create DashboardEntries for all followers of Roll" do
      @roll.add_follower(u1 = Factory.create(:user))
      @roll.add_follower(u2 = Factory.create(:user))
      @roll.add_follower(u3 = Factory.create(:user))
      user_ids = [u1.id, u2.id, u3.id]
      
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
        
      # all roll followers should have a DashboardEntry
      res[:dashboard_entries].size.should == 3
      res[:dashboard_entries].each { |dbe| dbe.persisted?.should == true }
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u1.id)
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u2.id)
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u3.id)
    end
  
    it "should create DashboardEntry for given :dashboard_user_id" do
      u = User.create
      
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :dashboard_user_id => u.id
        )
        
      #only the given dashboard_user_id should have a DashboardEntry
      res[:dashboard_entries].size.should == 1
      res[:dashboard_entries][0].persisted?.should == true
      res[:dashboard_entries][0].user_id.should == u.id
    end
  
    it "should create a Frame with a public Message" do
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
    
      res[:frame].persisted?.should == true
      res[:frame].creator.should == @frame_creator
      res[:frame].video.should == @video
      res[:frame].conversation.persisted?.should == true
      res[:frame].conversation.messages.size.should == 1
      res[:frame].conversation.messages[0].should == @message
      res[:frame].conversation.messages[0].public?.should == true
      res[:frame].conversation.public?.should == true
      res[:frame].roll.should == @roll
    end
  
    it "should create a Frame with a private Message" do
      @message.public = false
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )
    
      res[:frame].persisted?.should == true
      res[:frame].creator.should == @frame_creator
      res[:frame].video.should == @video
      res[:frame].conversation.persisted?.should == true
      res[:frame].conversation.messages.size.should == 1
      res[:frame].conversation.messages[0].should == @message
      res[:frame].conversation.messages[0].public?.should == false
      res[:frame].conversation.public?.should == false
      res[:frame].roll.should == @roll
    end
  
    it "should not create a Frame without Video" do
      lambda { GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => nil,
        :message => @message,
        :roll => @roll
        ) }.should raise_error(ArgumentError)
    end
  
    it "should not create a Frame without action" do
      lambda { GT::Framer.create_frame(
        :action => nil,
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        ) }.should raise_error(ArgumentError)
    end
  
    it "should not create a Frame without Roll or dashboard user" do
      lambda { GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => nil,
        :dashboard_user_id => nil
        ) }.should raise_error(ArgumentError)
    end

  end # /creating Frames

  context "re-rolling" do
    before(:each) do
      @video = Factory.create(:video, :thumbnail_url => "thum_url")
      @f1 = Factory.create(:frame, :video => @video)
      
      @roll_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
      @roll = Roll.new( :title => "title" )
      @roll.creator = @roll_creator
      @roll.save
    end
    
    it "should set the DashboardEntry metadata correctly" do
      @roll.add_follower(@roll_creator)
      res = GT::Framer.re_roll(@f1, Factory.create(:user), @roll)
      
      res[:dashboard_entries].size.should == 1
      res[:dashboard_entries][0].user.should == @roll_creator
      res[:dashboard_entries][0].action.should == DashboardEntry::ENTRY_TYPE[:re_roll]
      res[:dashboard_entries][0].frame.should == res[:frame]
      res[:dashboard_entries][0].roll.should == @roll
      res[:dashboard_entries][0].roll.should == res[:frame].roll
    end
    
    it "should create DashboardEntries for all users (except the re-reroller) following the Roll a Frame is re-rolled to" do
      @roll.add_follower(@roll_creator)
      @roll.add_follower(u1 = Factory.create(:user))
      @roll.add_follower(u2 = Factory.create(:user))
      @roll.add_follower(u3 = Factory.create(:user))
      user_ids = [@roll_creator.id, u1.id, u2.id, u3.id]
      
      # Re-roll some random frame on the roll this user created
      res = GT::Framer.re_roll(@f1, @roll_creator, @roll)
      
      # all roll followers should have a DashboardEntry
      res[:dashboard_entries].size.should == 3
      res[:dashboard_entries].each { |dbe| dbe.persisted?.should == true }
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should_not include(@roll_creator.id)
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u1.id)
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u2.id)
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u3.id)
    end
    
    it "should set the frame's roll's thumbnail_url if it's nil" do
      @roll.thumbnail_url.blank?.should == true
      
      res = GT::Framer.re_roll(@f1, Factory.create(:user), @roll)
    
      res[:frame].roll.thumbnail_url.should == @video.thumbnail_url
    end
    
    it "should not touch the frame's roll's thumbnail_url if it's already set" do
      @roll.update_attribute(:thumbnail_url, "something://el.se")
      
      res = GT::Framer.re_roll(@f1, Factory.create(:user), @roll)
    
      res[:frame].roll.thumbnail_url.should == "something://el.se"
    end
  end
  
  context "duping F1 as F2" do
    before(:each) do
      @f1 = Frame.new
      @f1.creator = Factory.create(:user)
      @f1.conversation = Conversation.new
      @f1.video = Factory.create(:video)
      @f1.roll = Factory.create(:roll, :creator => Factory.create(:user))
      @f1.save
      @u = Factory.create(:user)
      @r2 = Factory.create(:roll, :creator => @u)
    end
    
    it "should require original frame, not allow id" do
      lambda {
        GT::Framer.dupe_frame!(nil, @u, @r2)
      }.should raise_exception(ArgumentError)
    end    
    
    it "should accept user or user_id" do
      lambda {
        GT::Framer.dupe_frame!(@f1, @u, @r2)
      }.should_not raise_exception(ArgumentError)
      
      lambda {
        GT::Framer.dupe_frame!(@f1, @u.id, @r2)
      }.should_not raise_exception(ArgumentError)
    end
    
    it "should accept roll or roll_id" do
      lambda {
        GT::Framer.dupe_frame!(@f1, @u, @r2)
      }.should_not raise_exception(ArgumentError)
      
      lambda {
        GT::Framer.dupe_frame!(@f1, @u, @r2.id)
      }.should_not raise_exception(ArgumentError)
    end
    
    it "should copy F1's video_id, and conversation_id but have new roll id" do
      @f2 = GT::Framer.dupe_frame!(@f1, @u, @r2)
      
      @f2.video_id.should == @f1.video_id
      @f2.conversation_id.should == @f1.conversation_id
      @f2.roll_id.should_not == @f1.roll_id
    end
      
    it "should copy F1's score and upvoters" do
      u = Factory.create(:user)
      u.upvoted_roll = Factory.create(:roll, :creator => u)
      u.save
      @f1.upvote!(u)
      @f1.save
      @f2 = GT::Framer.dupe_frame!(@f1, @u, @r2)
      
      @f2.score.should be_within(0.001).of(@f1.score)
      @f2.upvoters.should == @f1.upvoters
    end
    
    it "should have the orig frame user's id" do
      @f2 = GT::Framer.dupe_frame!(@f1, @u, @r2)
      
      @f2.creator_id.should == @f2.creator_id
    end
    
    it "should copy the F1's ancestors, adding itself" do
      @f2 = GT::Framer.dupe_frame!(@f1, @u, @r2)
      
      @f2.frame_ancestors.should == (@f1.frame_ancestors + [@f1.id])
    end
    
  end

  context "removing dupe of Frame from Roll" do
    before(:each) do
      @roll_creator = Factory.create( :user )
      @roll = Roll.new( :title => "title" )
      @roll.creator = @roll_creator
      @roll.save
      
      @frame = Factory.create(:frame)
      
      @dupe = GT::Framer.dupe_frame!(@frame, @roll_creator, @roll)
    end
    
    it "should destroy the dupe of the Frame" do
      lambda {
        GT::Framer.remove_dupe_of_frame_from_roll!(@frame, @roll)
        Frame.find(@frame.id).should == @frame
        Frame.find(@dupe.id).should == nil
      }.should change { @roll.frames.count } .by(-1)
    end
    
  end

  context "creating a DashboardEntry" do
    before(:each) do
      @roll_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
      @roll = Roll.new( :title => "title" )
      @roll.creator = @roll_creator
      @roll.save
      
      @frame = Factory.create(:frame)
    end
    
    it "should create a DashboardEntry when given a Frame, action and User" do
      observer = Factory.create(:user)
      
      d = nil
      lambda {
        d = GT::Framer.create_dashboard_entry(@frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], observer)
      }.should change { DashboardEntry.count } .by 1
      
      d.size.should == 1
      d[0].persisted?.should == true
      d[0].frame.should == @frame
      d[0].user.should == observer
    end
  end

  context "backfilling DashboardEntries" do
    before(:each) do
      @roll_creator = Factory.create(:user)
      @roll = Factory.create(:roll, :title => "title", :creator => @roll_creator )
      
      @frame3 = Factory.create(:frame, :roll => @roll, :score => 10)
      @frame2 = Factory.create(:frame, :roll => @roll, :score => 11)
      @frame1 = Factory.create(:frame, :roll => @roll, :score => 12)
      @frame0 = Factory.create(:frame, :roll => @roll, :score => 13)
      
      @frame3.update_attribute(:score, 13)
      @frame2.update_attribute(:score, 14)
      @frame1.update_attribute(:score, 15)
      @frame0.update_attribute(:score, 16)
      
      @user = Factory.create(:user)
    end
    
    it "should backfill User's dashboard with 2 frames" do
      lambda {
        res = GT::Framer.backfill_dashboard_entries(@user, @roll, 2)
      }.should change { @user.dashboard_entries.count } .by 2
    end
    
    it "should backfill User's dashboard with 2 frames in the correct order" do
      GT::Framer.backfill_dashboard_entries(@user, @roll, 2)
      @user.dashboard_entries.count.should == 2
      @user.dashboard_entries[0].frame.should == @frame0
      @user.dashboard_entries[1].frame.should == @frame1
    end
    
    it "should backfill even if there aren't enough Frames" do
      lambda {
        res = GT::Framer.backfill_dashboard_entries(@user, @roll, 20)
      }.should change { @user.dashboard_entries.count } .by 4
    end
    
    it "shouldn't die if there aren't any frames" do
      empty_roll = Factory.create(:roll, :title => "title", :creator => @roll_creator )
       
      lambda {
        res = GT::Framer.backfill_dashboard_entries(@user, empty_roll, 20)
      }.should change { @user.dashboard_entries.count } .by 0
    end
  end

end
