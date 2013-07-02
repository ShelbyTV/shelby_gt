# encoding: UTF-8

require 'spec_helper'

require 'user_email_processor'

# UNIT test
describe GT::UserEmailProcessor do

  before(:each) do
    @user = Factory.create(:user)
    @user.viewed_roll = Factory.create(:roll, :creator => @user)
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

      context "with valid data" do
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

        context "process and send email" do

          before(:each) do
            @stub_cursor = {}
            @stub_cursor.should_receive(:each).and_yield({})
            User.stub_chain(:collection, :find).and_yield(@stub_cursor)
            User.should_receive(:load).and_return(@user)
          end

          it "should call create_new_dashboard_entry with video graph recommendation if there are no unwatched prioritized dashboard entries" do
            video_with_rec = Factory.create(:video)
            video_with_rec.recs << Factory.create(:recommendation, :recommended_video_id => video_with_rec.id)
            video_with_rec.save
            dbe_with_rec = Factory.create(:dashboard_entry, :user => @user, :video_id => video_with_rec.id)
            @user.dashboard_entries << dbe_with_rec

            @email_processor.should_receive(:create_new_dashboard_entry).with(@user, dbe_with_rec, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
            @email_processor.should_not_receive(:create_new_dashboard_entry_from_prioritized)

            @email_processor.process_and_send_rec_email
          end

          it "should call create_new_dashboard_entry_from_prioritized if there is an unwatched prioritized dashboard entry" do
            @pdbe = Factory.create(:prioritized_dashboard_entry, :user => @user, :watched_by_owner => false)

            @email_processor.should_receive(:create_new_dashboard_entry_from_prioritized).with(@user, @pdbe)
            @email_processor.should_not_receive(:create_new_dashboard_entry)

            @email_processor.process_and_send_rec_email
          end

        end

        context "dashboard entry scanning for video recs" do

          it "should only look for video recs if there are no prioritized dashboard recs" do
            @obj = {}
            DashboardEntry.stub(:collection).and_return(@obj)
            @obj.should_receive(:find).at_least(:once)
            @email_processor.scan_dashboard_entries_for_rec(@user)
          end

          it "should not scan for video recs if there is a prioritized dashboard rec for the user" do
            @pdbe = Factory.create(:prioritized_dashboard_entry, :user => @user, :watched_by_owner => false)
            DashboardEntry.should_not_receive(:collection)
            @email_processor.scan_dashboard_entries_for_rec(@user)
          end

          it "should return nil if no video recs found in users dashboard" do
            @email_processor.scan_dashboard_entries_for_rec(@user).should eql nil
          end

          it "should return a regular dbe if one has a video with a rec" do
            video_with_rec = Factory.create(:video)
            video_with_rec.recs << Factory.create(:recommendation, :recommended_video_id => video_with_rec.id)
            video_with_rec.save
            dbe_with_rec = Factory.create(:dashboard_entry, :user => @user, :video_id => video_with_rec.id)
            @user.dashboard_entries << dbe_with_rec

            result = @email_processor.scan_dashboard_entries_for_rec(@user)
            result["_id"].should eql dbe_with_rec.id
            result.should be_an_instance_of(DashboardEntry)
          end

        end

        context "dashboard entry scanning for prioritized dashboard entry recs" do
          it "should return a prioritized dashboard entry if a possibly unwatched one exists" do
            @pdbe = Factory.create(:prioritized_dashboard_entry, :user => @user, :watched_by_owner => false)
            result = @email_processor.scan_dashboard_entries_for_rec(@user)
            result.should eql(@pdbe)
            result.should be_an_instance_of(PrioritizedDashboardEntry)
          end

          it "should not return a prioritized dashboard entry if all of them are watched" do
            @pdbe = Factory.create(:prioritized_dashboard_entry, :user => @user, :watched_by_owner => true)
            result = @email_processor.scan_dashboard_entries_for_rec(@user)
            result.should_not be_eql(@pdbe)
            result.should_not be_an_instance_of(PrioritizedDashboardEntry)
          end
        end

      end

      context "creating a new dashboard entry from one with a video rec" do
        before(:each) do
          @email_processor = GT::UserEmailProcessor.new
          @v = Factory.create(:video)
          @v.recs << Factory.create(:recommendation, :recommended_video_id => @v.id)
          @f = Factory.create(:frame, :video => @v, :creator => @user )
          @dbe = Factory.create(:dashboard_entry, :frame => @f, :user => @user, :video_id => @v.id)
          @user.dashboard_entries << @dbe
        end

        it "should return argument error if a dbe is not given" do
          lambda {
            @email_processor.create_new_dashboard_entry(@user)
          }.should raise_error(ArgumentError)
        end

        it "should create something that is a dbe " do
          @email_processor.create_new_dashboard_entry(@user, @dbe, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]).class.should eql DashboardEntry
        end

        it "should have a video that is the video rec of the src frame" do
          new_dbe = @email_processor.create_new_dashboard_entry(@user, @dbe, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
          frame = Frame.find(new_dbe.frame_id)
          frame.video_id.should eq @dbe.video.recs.first.recommended_video_id
        end

        it "should not add video if user watched it already" do
          dbe_with_rec = Factory.create(:dashboard_entry, :user => @user, :frame => @f, :video_id => @v.id)
          @user.dashboard_entries << dbe_with_rec

          v2 = Factory.create(:video)
          v2.recs << Factory.create(:recommendation, :recommended_video_id => v2.id)
          f2 = Factory.create(:frame, :video => v2, :creator => @user )
          dbe2 = Factory.create(:dashboard_entry, :frame => f2, :user => @user, :video_id => v2.id)
          @user.dashboard_entries << dbe2

          dupe = GT::Framer.dupe_frame!(@f, @user.id, @user.viewed_roll_id)

          new_dbe = @email_processor.create_new_dashboard_entry(@user, @dbe, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
          new_dbe.should eq nil
        end

      end

      context "creating a new dashboard entry from a prioritized dashboard entry" do

        before(:each) do
          @email_processor = GT::UserEmailProcessor.new
          @v = Factory.create(:video)
          @f = Factory.create(:frame, :video => @v)
          @friend_user = Factory.create(:user)
          @pdbe = Factory.create(:prioritized_dashboard_entry, {
            :frame => @f,
            :user => @user,
            :video_id => @v.id,
            :friend_sharers_array => [@friend_user.id.to_s],
            :friend_viewers_array => [@friend_user.id.to_s],
            :friend_likers_array => [@friend_user.id.to_s],
            :friend_rollers_array => [@friend_user.id.to_s],
            :friend_complete_viewers_array => [@friend_user.id.to_s]
          })
        end

        it "should return a dashboard entry containing the video from the prioritized dashboard entry" do
          result = @email_processor.create_new_dashboard_entry_from_prioritized(@user, @pdbe)
          result.should be_an_instance_of(DashboardEntry)
          result.user.should == @user
          result.frame.should_not == @f
          result.frame.video.should == @v
          result.action.should == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
        end

        it "should have prioritized dashboard friend arrays copied onto it" do
          result = @email_processor.create_new_dashboard_entry_from_prioritized(@user, @pdbe)
          result.friend_sharers_array.should include(@friend_user.id.to_s)
          result.friend_viewers_array.should include(@friend_user.id.to_s)
          result.friend_likers_array.should include(@friend_user.id.to_s)
          result.friend_rollers_array.should include(@friend_user.id.to_s)
          result.friend_complete_viewers_array.should include(@friend_user.id.to_s)
        end

      end

    end

  end
end
