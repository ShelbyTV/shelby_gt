# encoding: UTF-8

require 'spec_helper'

require 'user_email_processor'

# UNIT test
describe GT::UserEmailProcessor do

  before(:each) do
    @user = Factory.create(:user)
  end

  context "send_rec_email" do

    context "private methods" do
      before(:each) do
        @email_processor = GT::UserEmailProcessor.new
      end

      context "real user check" do
        it "should return true if its real user type" do
          @user["gt_enabled"] = true
          @user["user_type"] = User::USER_TYPE[:real]
          @email_processor.is_real?(@user).should eql true
        end

        it "should return true if its converted user type" do
          @user["gt_enabled"] = true
          @user["user_type"] = User::USER_TYPE[:converted]
          @email_processor.is_real?(@user).should eql true
        end

        it "should return null if its real or converted user type but not gt_enabled" do
          @user["gt_enabled"] = false
          @email_processor.is_real?(@user).should eql false
        end

        it "should return false if user is fake" do
          @user["user_type"] = User::USER_TYPE[:faux]
          @email_processor.is_real?(@user).should eql false
        end
      end

      context "dashboard entry scanning for video recs" do
         before(:each) do
          @email_processor = GT::UserEmailProcessor.new
          @user = Factory.create(:user)
          30.times do |i|
            v = Factory.create(:video)
            f = Factory.create(:frame, :video => v, :creator => @user )
            @dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id)
            @user.dashboard_entries << @dbe
          end
        end

        it "should return nil if no video recs found in users dashboard" do
          @email_processor.scan_dashboard_entries_for_rec(@user).should eql nil
        end

        it "should return a dbe if one has a video with a rec" do
          video_with_rec = Factory.create(:video)
          video_with_rec.recs << Factory.create(:recommendation, :recommended_video_id => video_with_rec.id)
          video_with_rec.save
          dbe_with_rec = Factory.create(:dashboard_entry, :user => @user, :video_id => video_with_rec.id)
          @user.dashboard_entries << dbe_with_rec

          @email_processor.scan_dashboard_entries_for_rec(@user)["_id"].should eql dbe_with_rec.id
        end

      end

      context "creating a new dashbaord entry from one with a rec" do
        before(:each) do
          @email_processor = GT::UserEmailProcessor.new
          v = Factory.create(:video)
          v.recs << Factory.create(:recommendation, :recommended_video_id => v.id)
          f = Factory.create(:frame, :video => v, :creator => @user )
          @dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id)
          @user.dashboard_entries << @dbe
        end

        it "should return argument error if a dbe is not given" do
          lambda {
            @email_processor.create_new_dashboard_entry(@user)
          }.should raise_error(ArgumentError)
        end

        it "should create something that is a dbe " do
          @email_processor.create_new_dashboard_entry(@dbe, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]).class.should eql DashboardEntry
        end

        it "should have a video that is the video rec of the src frame" do
          new_dbe = @email_processor.create_new_dashboard_entry(@dbe, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
          frame = Frame.find(new_dbe.frame_id)
          frame.video_id.should eq @dbe.video.recs.first._id
        end

      end

    end

  end
end
