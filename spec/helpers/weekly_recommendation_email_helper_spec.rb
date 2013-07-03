require 'spec_helper'

describe WeeklyRecommendationEmailHelper do

  context "message_text" do

    context "video graph recommendations" do
      before(:each) do
        @sharing_user = Factory.create(:user)
        @src_frame = Factory.create(:frame, :creator => @sharing_user)
        @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], :src_frame => @src_frame)
      end

      it "should start with the right text" do
        message_text(@dbe).should start_with("We've discovered that people like #{@sharing_user.nickname} are")
      end
    end

    context "entertainment graph recommendations" do
      before(:each) do
        @friend_user = Factory.create(:user)
        @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation])
        @dbe.friend_likers_array = [@friend_user.id]
      end

      it "should return the right message for one friend user" do
        message_text(@dbe, @dbe.all_associated_friends).should eql("We've discovered that #{@friend_user.nickname} checked out this video.")
      end

      it "should return the right message for two friend users" do
        friend_user = Factory.create(:user)
        @dbe.friend_likers_array << friend_user.id
        message_text(@dbe, @dbe.all_associated_friends).should start_with("#{@friend_user.nickname} and 1 other are")
      end

      it "should return the right message for three or more friend users" do
        (1..2).each do
          friend_user = Factory.create(:user)
          @dbe.friend_likers_array << friend_user.id
        end
        message_text(@dbe, @dbe.all_associated_friends).should start_with("#{@friend_user.nickname} and 2 others are")
      end

      it "should count friend users from the other friend arrays" do
        friend_user = Factory.create(:user)
        @dbe.friend_likers_array << friend_user.id
        friend_user = Factory.create(:user)
        @dbe.friend_viewers_array << friend_user.id
        message_text(@dbe, @dbe.all_associated_friends).should start_with("#{@friend_user.nickname} and 2 others are")
      end
    end

  end

end