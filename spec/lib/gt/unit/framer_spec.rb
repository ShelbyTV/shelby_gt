require 'spec_helper'
require 'framer'
require 'video_manager'

# UNIT test
# N.B. GT::Framer.re_roll is also tested by unit/frame_spec.rb
describe GT::Framer do
  
  context "creating Frames" do
    before(:each) do
      @video = Factory.create(:video)
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
      @roll.add_follower(u1 = User.create)
      @roll.add_follower(u2 = User.create)
      @roll.add_follower(u3 = User.create)
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
  
    it "should not create a Frame without Creator" do
      lambda { GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => nil,
        :video => @video,
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
      @f1 = Frame.create
      
      @roll_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
      @roll = Roll.new( :title => "title" )
      @roll.creator = @roll_creator
      @roll.save
    end
    
    it "should set the DashboardEntry metadata correctly" do
      @roll.add_follower(@roll_creator)
      res = GT::Framer.re_roll(@f1, @roll_creator, @roll)
      
      res[:dashboard_entries].size.should == 1
      res[:dashboard_entries][0].user.should == @roll_creator
      res[:dashboard_entries][0].action.should == DashboardEntry::ENTRY_TYPE[:re_roll]
      res[:dashboard_entries][0].frame.should == res[:frame]
      res[:dashboard_entries][0].roll.should == @roll
      res[:dashboard_entries][0].roll.should == res[:frame].roll
    end
    
    it "should create DashboardEntries for all users following the Roll a Frame is re-rolled to" do
      @roll.add_follower(@roll_creator)
      @roll.add_follower(u1 = User.create)
      @roll.add_follower(u2 = User.create)
      @roll.add_follower(u3 = User.create)
      user_ids = [@roll_creator.id, u1.id, u2.id, u3.id]
      
      # Re-roll some random frame on the roll this user created
      res = GT::Framer.re_roll(@f1, @roll_creator, @roll)
      
      # all roll followers should have a DashboardEntry
      res[:dashboard_entries].size.should == 4
      res[:dashboard_entries].each { |dbe| dbe.persisted?.should == true }
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(@roll_creator.id)
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u1.id)
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u2.id)
      res[:dashboard_entries].map { |dbe| dbe.user_id }.should include(u3.id)
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
      
      @f2.score.should == @f1.score
      @f2.upvoters.should == @f1.upvoters
    end
    
    it "should have the duping user's id" do
      @f2 = GT::Framer.dupe_frame!(@f1, @u, @r2)
      
      @f2.creator_id.should == @u.id
    end
    
    it "should copy the F1's ancestors, adding itself" do
      @f2 = GT::Framer.dupe_frame!(@f1, @u, @r2)
      
      @f2.frame_ancestors.should == (@f1.frame_ancestors + [@f1.id])
    end
    
  end
  
  context "creating a frame from a video url" do
    before(:each) do
      @video_url = "http://some.video.url.com/of_a_movie_i_like"
      @video = Factory.create(:video, :source_url => @video_url)
      @frame_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
      @message_text = "boy do i like this video"
      
      @roll_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
      @roll = Roll.new( :title => "title" )
      @roll.creator = @roll_creator
      @roll.save
      
      GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return(@video)
    end
    
    it "should create a frame given from a video url" do
      GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return(@video)
      res = GT::Framer.create_frame_from_url(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video_url => @video_url,
          :message_text => @message_text,
          :roll => @roll
          )
    
      res[:frame].persisted?.should == true
      res[:frame].creator.should == @frame_creator
      res[:frame].video.should == @video
      res[:frame].conversation.persisted?.should == true
      res[:frame].conversation.messages.size.should == 1
      res[:frame].conversation.messages[0].text.should == @message_text
      res[:frame].conversation.messages[0].persisted?.should == true
      res[:frame].roll.should == @roll
    end
    
    it "should create a new frame with no message when without any message text provided" do
      res = GT::Framer.create_frame_from_url(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video_url => @video_url,
          :roll => @roll
          )
    
      res[:frame].persisted?.should == true
      res[:frame].creator.should == @frame_creator
      res[:frame].video.should == @video
      res[:frame].conversation.persisted?.should == true
      res[:frame].conversation.messages.size.should == 0
    end
    
  end

end