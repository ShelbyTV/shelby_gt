require 'spec_helper'
require 'framer'

# UNIT test
# N.B. GT::Framer.re_roll is also tested by unit/frame_spec.rb
describe GT::Framer do
  
  context "creating Frames" do
    before(:each) do
      @video = Video.create
      @frame_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
      @message = Message.new
    
    
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
      @roll.add_follower(u1 = User.create(:nickname => "nick"))
      @roll.add_follower(u2 = User.create(:nickname => "nick"))
      @roll.add_follower(u3 = User.create(:nickname => "nick"))
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
      u = User.create(:nickname => "nick")
      
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
  
    it "should create a Frame without Message" do
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
      @roll.add_follower(u1 = User.create(:nickname => "nick1"))
      @roll.add_follower(u2 = User.create(:nickname => "nick2"))
      @roll.add_follower(u3 = User.create(:nickname => "nick3"))
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

end