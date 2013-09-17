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
        }.not_to raise_error
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

  context "get_dot_tv_stats_for_recent_frames" do

    context "arguments" do

      it "should return an error if no user is supplied" do
        expect {
          GT::UserStatsManager.get_frames_rolled_since(nil, nil)
        }.to raise_error(ArgumentError)
      end

      it "should return an error if no time supplied" do
        expect {
          GT::UserStatsManager.get_frames_rolled_since(@user, nil)
        }.to raise_error(ArgumentError)
      end

      it "should return no errors if all arguments are supplied and valid" do
        expect {
          GT::UserStatsManager.get_frames_rolled_since(@user, Time.now)
        }.not_to raise_error
      end

    end

    context "results" do
      before(:each) do
        @user_public_roll = Factory.create(:roll, :creator => @user)
        @user.public_roll = @user_public_roll

        @frame1 = Factory.create(:frame, :roll => @user_public_roll)
        @time1 = Time.now
        @frame1.score = (@time1.to_f - Frame::SHELBY_EPOCH.to_f) / Frame::TIME_DIVISOR
        @frame1.save

        @frame2 = Factory.create(:frame, :roll => @user_public_roll)
        @time2 = Time.now.advance(:minutes => 5)
        @frame2.score = (@time2.to_f - Frame::SHELBY_EPOCH.to_f) / Frame::TIME_DIVISOR
        @frame2.save

        @frame3 = Factory.create(:frame, :roll => @user_public_roll)
        @time3 = Time.now.advance(:minutes => 10)
        @frame3.score = (@time3.to_f - Frame::SHELBY_EPOCH.to_f) / Frame::TIME_DIVISOR
        @frame3.save
      end

      it "should return the count of all frames in the roll if the passed time is before the created time of the first frame" do
        count = GT::UserStatsManager.get_frames_rolled_since(@user, @time1.ago(1))
        count.should == @user_public_roll.frame_count
      end

      it "should return one if the passed time is the created time of the last frame" do
        count = GT::UserStatsManager.get_frames_rolled_since(@user, @time3)
        count.should == 1
      end

      it "should return zero if the passed time is after the created time of the last frame" do
        count = GT::UserStatsManager.get_frames_rolled_since(@user, @time3.advance(:seconds => 1))
        count.should == 0
      end
    end

  end

end