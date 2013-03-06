# encoding: UTF-8

require 'spec_helper'

require 'user_stats_manager'

# UNIT test
describe GT::UserStatsManager do

  before(:each) do
    @user = Factory.create(:user)
  end

  context "get_dot_tv_stats_for_recent_frames" do

    context "arguments" do

      it "should return an error if no user is supplied" do
        expect {
          GT::UserStatsManager.get_dot_tv_stats_for_recent_frames(nil, nil)
        }.to raise_error(ArgumentError)
      end

      it "should return an error if no num_frames is supplied" do
        expect {
          GT::UserStatsManager.get_dot_tv_stats_for_recent_frames(@user, nil)
        }.to raise_error(ArgumentError)
      end

      it "should return no errors if all arguments are supplied" do
        expect {
          GT::UserStatsManager.get_dot_tv_stats_for_recent_frames(@user, 3)
        }.not_to raise_error(ArgumentError)
      end

    end

    context "results" do
      before(:each) do
        @user_public_roll = Factory.create(:roll, :creator => @user)
        @user.public_roll = @user_public_roll
      end

      context "length" do
        it "should return an empty array if there are no frames on the user personal roll" do
          stats = GT::UserStatsManager.get_dot_tv_stats_for_recent_frames(@user, 3)
          stats.should have(0).items
        end

        it "should return num_frames results if there are num_frames or greater frames on the user's public roll" do
          @frame1 = Factory.create(:frame, :roll => @user_public_roll)
          @frame2 = Factory.create(:frame, :roll => @user_public_roll)
          @frame3 = Factory.create(:frame, :roll => @user_public_roll)
          @frame4 = Factory.create(:frame, :roll => @user_public_roll)

          stats = GT::UserStatsManager.get_dot_tv_stats_for_recent_frames(@user, 3)
          stats.should have(3).items
        end

        it "should return as many results as there are frames in user's public roll if the number of frames in the roll is less than num_frames" do
          @frame1 = Factory.create(:frame, :roll => @user_public_roll)
          @frame2 = Factory.create(:frame, :roll => @user_public_roll)

          stats = GT::UserStatsManager.get_dot_tv_stats_for_recent_frames(@user, 3)
          stats.should have(2).items
        end
      end

      context "content" do

        it "should return an object containing each frame" do
          frame = Factory.create(:frame, :roll => @user_public_roll, :like_count =>3, :view_count => 4)
          stats = GT::UserStatsManager.get_dot_tv_stats_for_recent_frames(@user, 1)

          stats[0].frame.should == frame
        end

      end
    end

  end

end