require 'spec_helper'

describe WeeklyRecommendationEmailHelper do

  context "multiple recommendations" do
    before(:each) do
      dbe1 = Factory.create(:dashboard_entry)
      dbe2 = Factory.create(:dashboard_entry)
      @dbes = [dbe1, dbe2]
    end

    it "returns the right message_text" do
      message_text(@dbes).should eql "Some video to share with friends and family..."
    end

    it "returns the right message_subject" do
      message_subject(@dbes).should eql "From us to you. Enjoy!"
    end

  end

  context "single video graph recommendation" do
    before(:each) do
      @sharing_user = Factory.create(:user)
      @src_frame = Factory.create(:frame, :creator => @sharing_user)
      @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], :src_frame => @src_frame)
    end

    context "share (heavy_weight)" do

      it "returns the right message_text" do
        message_text([@dbe]).should eql "This video is similar to videos #{@sharing_user.name} has shared"
      end

      it "returns the right message_subject" do
        message_subject([@dbe]).should eql "Watch this, it's similar to videos #{@sharing_user.name} has shared"
      end

    end

    context "like (light_weight)" do

      before(:each) do
        @src_frame.frame_type = Frame::FRAME_TYPE[:light_weight]
      end

      it "returns the right message_text" do
        message_text([@dbe]).should eql "This video is similar to videos #{@sharing_user.name} has liked"
      end

      it "returns the right message_subject" do
        message_subject([@dbe]).should eql "Watch this, it's similar to videos #{@sharing_user.name} has liked"
      end

    end

  end

  context "single mortar recommendation" do
    before(:each) do
      @src_video = Factory.create(:video)
      @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation], :src_video => @src_video)
    end

    it "returns the right message_text" do
      message_text([@dbe]).should eql "This video is similar to \"#{@src_video.title}\""
    end

    it "returns the right message_subject" do
      message_subject([@dbe]).should eql "A video because you liked: \"#{@src_video.title}\""
    end

  end

  context "single channel recommendation" do
    before(:each) do
      @sharer = Factory.create(:user)
      @frame = Factory.create(:frame, :creator => @sharer)
      @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation], :frame => @frame)
    end

    context "share (heavy_weight)" do

      it "returns the right message_text" do
        message_text([@dbe]).should eql "This featured video was shared by #{@sharer.name}"
      end

      it "returns the right message_subject" do
        message_subject([@dbe]).should eql "This video was shared by #{@sharer.name}. Check it out."
      end

    end

    context "like (light_weight)" do

      before(:each) do
        @frame.frame_type = Frame::FRAME_TYPE[:light_weight]
      end

      it "returns the right message_text" do
        message_text([@dbe]).should eql "This featured video was liked by #{@sharer.name}"
      end

      it "returns the right message_subject" do
        message_subject([@dbe]).should eql "This video was liked by #{@sharer.name}. Check it out."
      end

    end

  end

  context "single entertainment graph recommendations" do
    before(:each) do
      @friend_user = Factory.create(:user)
      @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation])
      @dbe.friend_likers_array = [@friend_user.id]
    end

    context "message_text" do

      it "should return the right message for one friend user" do
        message_text([@dbe]).should eql("We've discovered that #{@friend_user.name} checked out this video.")
      end

      it "should return the right message for two friend users" do
        friend_user = Factory.create(:user)
        @dbe.friend_likers_array << friend_user.id
        message_text([@dbe]).should start_with("#{@friend_user.name} and 1 other are")
      end

      it "should return the right message for three or more friend users" do
        (1..2).each do
          friend_user = Factory.create(:user)
          @dbe.friend_likers_array << friend_user.id
        end
        message_text([@dbe]).should start_with("#{@friend_user.name} and 2 others are")
      end

      it "should count friend users from the other friend arrays" do
        friend_user = Factory.create(:user)
        @dbe.friend_likers_array << friend_user.id
        friend_user = Factory.create(:user)
        @dbe.friend_viewers_array << friend_user.id
        message_text([@dbe]).should start_with("#{@friend_user.name} and 2 others are")
      end

    end

    context "message_subject" do

      it "should return the right subject for one friend user" do
        message_subject([@dbe]).should eql("Watch this video that #{@friend_user.name} watched")
      end

      it "should return the right subject for two friend users" do
        friend_user = Factory.create(:user)
        @dbe.friend_likers_array << friend_user.id
        message_subject([@dbe]).should eql("Watch this video that #{@friend_user.name} and 1 other shared, liked, and watched")
      end

      it "should return the right message for three or more friend users" do
        (1..2).each do
          friend_user = Factory.create(:user)
          @dbe.friend_likers_array << friend_user.id
        end
        message_subject([@dbe]).should eql("Watch this video that #{@friend_user.name} and 2 others shared, liked, and watched")
      end

    end

  end


end
