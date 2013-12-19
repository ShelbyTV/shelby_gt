require 'spec_helper'
require 'framer'
require 'video_manager'

# UNIT test
# N.B. GT::Framer.re_roll is also tested by unit/frame_spec.rb
describe GT::Framer do

  context "creating Frames" do
    before(:each) do
      @video = Factory.create(:video, :thumbnail_url => "thum_url")
      @frame_creator = Factory.create(:user)
      @message = Message.new
      @message.public = true

      @roll_creator = Factory.create(:user)
      @roll = Factory.create(:roll, :creator => @roll_creator)
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
      res[:frame].frame_type.should == Frame::FRAME_TYPE[:heavy_weight]
    end

    it "should not persist anything if persist option is set to false" do
      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll,
        :persist => false
        )

      res[:frame].persisted?.should_not == true
      res[:frame].creator.should == @frame_creator
      res[:frame].video.should == @video
      res[:frame].conversation.should be_nil
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
      @roll.creator_thumbnail_url.blank?.should == true

      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )

      res[:frame].roll.creator_thumbnail_url.should == @video.thumbnail_url
    end

    it "should not touch the frame's roll's thumbnail_url if it's already set" do
      @roll.update_attribute(:creator_thumbnail_url, "something://el.se")

      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )

      res[:frame].roll.creator_thumbnail_url.should == "something://el.se"
    end

    it "should set the roll's first_frame_thumbnail_url everytime a frame is added to a roll" do
      res1 = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll
        )

      res1[:frame].roll.first_frame_thumbnail_url.should == @video.thumbnail_url

      vid2 = @video
      vid2.thumbnail_url = "http://test.ing"; vid2.save

      res2 = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => vid2,
        :message => @message,
        :roll => @roll
        )

        res1[:frame].roll.first_frame_thumbnail_url.should == vid2.thumbnail_url
    end

    it "should create no DashboardEntries if the roll has no followers" do
      expect {
        res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :roll => @roll
          )
      }.not_to change(DashboardEntry, :count)
    end

    it "should create a DashboardEntry for the Roll's single follower" do
      @roll.add_follower(@roll_creator)

      #only the rolls creator should have a DashboardEntry
      expect {
        @res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :roll => @roll
          )
      }.to change(DashboardEntry, :count).by(1)

      #by default doesn't return the dashboard_entries
      @res.should_not have_key(:dashboard_entries)

      dbe = DashboardEntry.last
      dbe.user_id.should == @roll_creator.id
      dbe.user.should == @roll_creator
      dbe.roll.should == @roll
      dbe.frame.should == @res[:frame]
      dbe.src_frame.should be_nil
      dbe.src_frame_id.should be_nil
      dbe.src_video.should be_nil
      dbe.src_video_id.should be_nil
      dbe.friend_sharers_array.should == []
      dbe.friend_viewers_array.should == []
      dbe.friend_likers_array.should == []
      dbe.friend_rollers_array.should == []
      dbe.friend_complete_viewers_array.should == []
      dbe.video.should == @video
      dbe.actor.should == @frame_creator
      dbe.read?.should == false
      dbe.action.should == DashboardEntry::ENTRY_TYPE[:new_social_frame]
    end

    it "returns the created dashboard_entries if :return_dbe_models option is true" do
      @roll.add_follower(@roll_creator)

      res = GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => @message,
        :roll => @roll,
        :return_dbe_models => true
        )

      res[:dashboard_entries].length.should == 1

      dbe = res[:dashboard_entries][0]
      dbe.user_id.should == @roll_creator.id
      dbe.user.should == @roll_creator
      dbe.roll.should == @roll
      dbe.frame.should == res[:frame]
      dbe.src_frame.should be_nil
      dbe.src_frame_id.should be_nil
      dbe.src_video.should be_nil
      dbe.src_video_id.should be_nil
      dbe.friend_sharers_array.should == []
      dbe.friend_viewers_array.should == []
      dbe.friend_likers_array.should == []
      dbe.friend_rollers_array.should == []
      dbe.friend_complete_viewers_array.should == []
      dbe.video.should == @video
      dbe.actor.should == @frame_creator
      dbe.read?.should == false
      dbe.action.should == DashboardEntry::ENTRY_TYPE[:new_social_frame]

      dbe.reload
      dbe.persisted?.should == true
    end

    it "should not create a DashboardEntry for the Roll's single follower if persist option is set to false" do
      @roll.add_follower(@roll_creator)

      expect {
        GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :roll => @roll,
          :persist => false
          )
      }.not_to change(DashboardEntry, :count)
    end

    it "should create DashboardEntries for all followers of Roll" do
      @roll.add_follower(u1 = Factory.create(:user))
      @roll.add_follower(u2 = Factory.create(:user))
      @roll.add_follower(u3 = Factory.create(:user))
      user_ids = [u1.id, u2.id, u3.id]

      expect {
        GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :roll => @roll
          )
      }.to change(DashboardEntry, :count).by(3)

      DashboardEntry.sort(:_id.desc).limit(3).map { |dbe| dbe.user_id }.should == user_ids.reverse
    end

    it "should create DashboardEntry for given :dashboard_user_id" do
      u = Factory.create(:user)

      expect {
        @res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :dashboard_user_id => u.id
          )
      }.to change(DashboardEntry, :count).by(1)

      #only the given dashboard_user_id should have a DashboardEntry
      dbe = DashboardEntry.last
      dbe.user_id.should == u.id
      dbe.frame.should == @res[:frame]
      dbe.frame.persisted?.should == true
      dbe.src_frame.should be_nil
      dbe.src_frame_id.should be_nil
      dbe.src_video.should be_nil
      dbe.src_video_id.should be_nil
      dbe.friend_sharers_array.should == []
      dbe.friend_viewers_array.should == []
      dbe.friend_likers_array.should == []
      dbe.friend_rollers_array.should == []
      dbe.friend_complete_viewers_array.should == []
    end

    it "should not persist anything for given :dashboard_user_id if persist option is set to false" do
      u = Factory.create(:user)

      expect {
        @res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :dashboard_user_id => u.id,
          :persist => false
          )
      }.not_to change(DashboardEntry, :count)

      @res[:frame].persisted?.should_not == true
      @res[:frame].creator.should == @frame_creator
      @res[:frame].video.should == @video
      @res[:frame].conversation.should be_nil
    end

    it "should pass through options for DashboardEntry creation" do
      u = Factory.create(:user)
      friend_user = Factory.create(:user)
      friend_user_id_string = friend_user.id.to_s
      f = Factory.create(:frame)

      expect {
        GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :dashboard_user_id => u.id,
          :dashboard_entry_options => {
            :src_frame_id => f.id,
            :friend_sharers_array => [friend_user_id_string],
            :friend_viewers_array => [friend_user_id_string],
            :friend_likers_array => [friend_user_id_string],
            :friend_rollers_array => [friend_user_id_string],
            :friend_complete_viewers_array => [friend_user_id_string]
          }
          )
      }.to change(DashboardEntry, :count).by(1)

      dbe = DashboardEntry.last
      dbe.src_frame.should == f
      dbe.src_frame_id.should == f.id
      dbe.friend_sharers_array.should == [friend_user_id_string]
      dbe.friend_viewers_array.should == [friend_user_id_string]
      dbe.friend_likers_array.should == [friend_user_id_string]
      dbe.friend_rollers_array.should == [friend_user_id_string]
      dbe.friend_complete_viewers_array.should == [friend_user_id_string]
    end

    it "should set the DashboardEntry's id when creation_time is specified in :dashboard_entry_options" do
      u = Factory.create(:user)
      creation_time = 4.minutes.ago

      expect {
        @res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :dashboard_user_id => u.id,
          :dashboard_entry_options => {
            :creation_time => creation_time
          },
          :return_dbe_models => true
          )
      }.to change(DashboardEntry, :count).by(1)

      @res[:dashboard_entries][0].id.generation_time.to_i.should == creation_time.to_i
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

    it "should not create a Frame without Video or video_id" do
      lambda { GT::Framer.create_frame(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => nil,
        :video_id => nil,
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

    context "asynchronous DashboardEntry creation" do

      it "creates and returns a frame the same as in normal mode" do
        @roll.add_follower(@roll_creator)
        MongoMapper::Plugins::IdentityMap.clear

        expect {
          @res = GT::Framer.create_frame(
            :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
            :creator => @frame_creator,
            :video => @video,
            :message => @message,
            :roll => @roll,
            :async_dashboard_entries => true
            )
        }.to change { Frame.count }.by 1

        @res[:frame].should be_a Frame
      end

      it "should create a DashboardEntry for the Roll's single follower" do
          @roll.add_follower(@roll_creator)
          ResqueSpec.reset!
          MongoMapper::Plugins::IdentityMap.clear

          expect {
            @res = GT::Framer.create_frame(
              :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
              :creator => @frame_creator,
              :video => @video,
              :message => @message,
              :roll => @roll,
              :async_dashboard_entries => true
              )
          }.not_to change { DashboardEntry.count }

          # since the creation is asynchronous, no dbes should be returned
          @res.should_not have_key(:dashboard_entries)

          expect { ResqueSpec.perform_next(:dashboard_entries_queue) }.to change { DashboardEntry.count }.by 1

          dbe = DashboardEntry.last
          dbe.user_id.should == @roll_creator.id
          dbe.user.should == @roll_creator
          dbe.roll.should == @roll
          dbe.frame.should == @res[:frame]
          dbe.src_frame.should be_nil
          dbe.src_frame_id.should be_nil
          dbe.src_video.should be_nil
          dbe.src_video_id.should be_nil
          dbe.friend_sharers_array.should == []
          dbe.friend_viewers_array.should == []
          dbe.friend_likers_array.should == []
          dbe.friend_rollers_array.should == []
          dbe.friend_complete_viewers_array.should == []
          dbe.video.should == @video
          dbe.actor.should == @frame_creator
          dbe.read?.should == false
          dbe.action.should == DashboardEntry::ENTRY_TYPE[:new_social_frame]
        end

        it "raises an Exception if persist option is set to false" do
          expect {
            res = GT::Framer.create_frame(
              :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
              :creator => @frame_creator,
              :video => @video,
              :message => @message,
              :roll => @roll,
              :persist => false,
              :async_dashboard_entries => true
              )
          }.to raise_error(ArgumentError)
        end

        it "should create DashboardEntries for all followers of Roll" do
          @roll.add_follower(u1 = Factory.create(:user))
          @roll.add_follower(u2 = Factory.create(:user))
          @roll.add_follower(u3 = Factory.create(:user))
          user_ids = [u1.id, u2.id, u3.id]
          ResqueSpec.reset!

          expect {
            @res = GT::Framer.create_frame(
              :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
              :creator => @frame_creator,
              :video => @video,
              :message => @message,
              :roll => @roll,
              :async_dashboard_entries => true
              )
          }.not_to change { DashboardEntry.count }

          # since the creation is asynchronous, no dbes should be returned
          @res.should_not have_key(:dashboard_entries)

          expect { ResqueSpec.perform_next(:dashboard_entries_queue) }.to change { DashboardEntry.count }.by 3

          dbes = DashboardEntry.sort(["_id", -1]).limit(3).all
          dbes.map { |dbe| dbe.user_id }.should == [u3.id, u2.id, u1.id]
        end

        it "should create DashboardEntry for given :dashboard_user_id" do
          u = Factory.create(:user)
          ResqueSpec.reset!

          expect {
            @res = GT::Framer.create_frame(
              :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
              :creator => @frame_creator,
              :video => @video,
              :message => @message,
              :dashboard_user_id => u.id,
              :async_dashboard_entries => true
              )
          }.not_to change { DashboardEntry.count }

          # since the creation is asynchronous, no dbes should be returned
          @res.should_not have_key(:dashboard_entries)

          expect { ResqueSpec.perform_next(:dashboard_entries_queue) }.to change { DashboardEntry.count }.by 1

          dbe = DashboardEntry.last
          dbe.user_id.should == u.id
          dbe.frame.should == @res[:frame]
          dbe.frame.persisted?.should == true
          dbe.src_frame.should be_nil
          dbe.src_frame_id.should be_nil
          dbe.src_video.should be_nil
          dbe.src_video_id.should be_nil
          dbe.friend_sharers_array.should == []
          dbe.friend_viewers_array.should == []
          dbe.friend_likers_array.should == []
          dbe.friend_rollers_array.should == []
          dbe.friend_complete_viewers_array.should == []
        end

        it "should pass through options for DashboardEntry creation" do
          u = Factory.create(:user)
          friend_user = Factory.create(:user)
          friend_user_id_string = friend_user.id.to_s
          f = Factory.create(:frame)
          ResqueSpec.reset!

          creation_time = 10.years.from_now

          expect {
            @res = GT::Framer.create_frame(
              :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
              :creator => @frame_creator,
              :video => @video,
              :message => @message,
              :dashboard_user_id => u.id,
              :dashboard_entry_options => {
                :src_frame_id => f.id,
                :friend_sharers_array => [friend_user_id_string],
                :friend_viewers_array => [friend_user_id_string],
                :friend_likers_array => [friend_user_id_string],
                :friend_rollers_array => [friend_user_id_string],
                :friend_complete_viewers_array => [friend_user_id_string],
                :creation_time => creation_time
              },
              :async_dashboard_entries => true
              )
          }.not_to change { DashboardEntry.count }

          # since the creation is asynchronous, no dbes should be returned
          @res.should_not have_key(:dashboard_entries)

          expect { ResqueSpec.perform_next(:dashboard_entries_queue) }.to change { DashboardEntry.count }.by 1

          dbe = DashboardEntry.sort(['_id', 1]).last
          dbe.id.generation_time.to_i.should == creation_time.to_i
          dbe.src_frame.should == f
          dbe.src_frame_id.should == f.id
          dbe.friend_sharers_array.should == [friend_user_id_string]
          dbe.friend_viewers_array.should == [friend_user_id_string]
          dbe.friend_likers_array.should == [friend_user_id_string]
          dbe.friend_rollers_array.should == [friend_user_id_string]
          dbe.friend_complete_viewers_array.should == [friend_user_id_string]
        end
    end

  end # /creating Frames

  context "re-rolling" do
    before(:each) do
      MongoMapper::Helper.drop_all_dbs
      MongoMapper::Helper.ensure_all_indexes

      @video = Factory.create(:video, :thumbnail_url => "thum_url")
      @frame_creator = Factory.create(:user)
      @f1 = Factory.create(:frame, :video => @video, :creator => @frame_creator)

      @roll_creator = Factory.create(:user)
      @roll = Factory.create(:roll, :creator => @roll_creator)
      @roll.save
    end

    it "should set the DashboardEntry metadata correctly" do
      @roll.add_follower(@roll_creator)
      ResqueSpec.reset!

      expect {
        @res = GT::Framer.re_roll(@f1, Factory.create(:user), @roll)
      }.not_to change { DashboardEntry.count}

      expect { ResqueSpec.perform_next(:dashboard_entries_queue) }.to change { DashboardEntry.count }.by 1

      dbe = DashboardEntry.last
      dbe.user.should == @roll_creator
      dbe.action.should == DashboardEntry::ENTRY_TYPE[:re_roll]
      dbe.frame.should == @res[:frame]
      dbe.src_frame.should be_nil
      dbe.src_frame_id.should be_nil
      dbe.src_video.should be_nil
      dbe.src_video_id.should be_nil
      dbe.friend_sharers_array.should == []
      dbe.friend_viewers_array.should == []
      dbe.friend_likers_array.should == []
      dbe.friend_rollers_array.should == []
      dbe.friend_complete_viewers_array.should == []
      dbe.roll.should == @roll
      dbe.roll.should == @res[:frame].roll
    end

    it "should create DashboardEntries for all users (except the re-reroller) following the Roll a Frame is re-rolled to" do
      @roll.add_follower(@roll_creator)
      @roll.add_follower(u1 = Factory.create(:user))
      @roll.add_follower(u2 = Factory.create(:user))
      @roll.add_follower(u3 = Factory.create(:user))
      user_ids = [@roll_creator.id, u1.id, u2.id, u3.id]
      ResqueSpec.reset!

      # Re-roll some random frame on the roll this user created
      expect {
        @res = GT::Framer.re_roll(@f1, @roll_creator, @roll)
      }.not_to change { DashboardEntry.count}

      expect { ResqueSpec.perform_next(:dashboard_entries_queue) }.to change { DashboardEntry.count }.by 3

      dbes = DashboardEntry.sort(["_id", -1]).all
      user_ids = dbes.map { |dbe| dbe.user_id }
      user_ids.should == [u3.id, u2.id, u1.id]
      user_ids.should_not include(@roll_creator.id)
    end

    it "adds a DashboardEntryCreator job to the queue to create DashboardEntries for followers" do
      @roll.add_follower(@roll_creator)
      @roll.add_follower(u1 = Factory.create(:user))
      @roll.add_follower(u2 = Factory.create(:user))
      @roll.add_follower(u3 = Factory.create(:user))

      new_frame = Factory.create(:frame, :creator => @roll_creator)
      GT::Framer.should_receive(:basic_re_roll).with(@f1, @roll_creator.id, @roll.id, {}).and_return(new_frame)
      GT::Framer.should_receive(:create_dashboard_entries_async).ordered().with([new_frame], DashboardEntry::ENTRY_TYPE[:re_roll], [u1.id, u2.id, u3.id])
      GT::Framer.should_receive(:create_dashboard_entries_async).ordered().with([@f1], DashboardEntry::ENTRY_TYPE[:share_notification], [@frame_creator.id], {:actor_id => @roll_creator.id})

      GT::Framer.re_roll(@f1, @roll_creator, @roll)
    end

    it "checks and sends a :like_notification for the likee if the frame_type is light_weight" do
      new_frame = Factory.create(:frame)
      GT::Framer.should_receive(:basic_re_roll).with(@f1, @roll_creator.id, @roll.id, {:frame_type => Frame::FRAME_TYPE[:light_weight]}).and_return(new_frame)
      GT::Framer.should_receive(:create_dashboard_entries_async).once().with([new_frame], DashboardEntry::ENTRY_TYPE[:re_roll], [])
      GT::NotificationManager.should_receive(:check_and_send_like_notification).with(@f1, @roll_creator, [:notification_center])

      GT::Framer.re_roll(@f1, @roll_creator, @roll, {:frame_type => Frame::FRAME_TYPE[:light_weight]})
    end

    it "checks and sends a :share_notification for the origin frame's creator if the frame_type is heavy_weight" do
      new_frame = Factory.create(:frame)
      GT::Framer.should_receive(:basic_re_roll).with(@f1, @roll_creator.id, @roll.id, {}).and_return(new_frame)
      GT::Framer.should_receive(:create_dashboard_entries_async).once().with([new_frame], DashboardEntry::ENTRY_TYPE[:re_roll], [])
      GT::NotificationManager.should_receive(:check_and_send_reroll_notification).with(@f1, new_frame, [:notification_center])

      GT::Framer.re_roll(@f1, @roll_creator, @roll)
    end

    it "should set the frame's roll's thumbnail_url if it's nil" do
      @roll.creator_thumbnail_url.blank?.should == true

      res = GT::Framer.re_roll(@f1, Factory.create(:user), @roll)

      res[:frame].roll.creator_thumbnail_url.should == @video.thumbnail_url
    end

    it "should not touch the frame's roll's thumbnail_url if it's already set" do
      @roll.update_attribute(:creator_thumbnail_url, "something://el.se")

      res = GT::Framer.re_roll(@f1, Factory.create(:user), @roll)

      res[:frame].roll.creator_thumbnail_url.should == "something://el.se"
    end

    it "should set the back-pointer frame.conversation.frame" do
      res = GT::Framer.re_roll(@f1, Factory.create(:user), @roll)

      res[:frame].conversation.frame.should == res[:frame]
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
      }.should raise_error
    end

    it "should accept user or user_id" do
      lambda {
        GT::Framer.dupe_frame!(@f1, @u, @r2)
      }.should_not raise_error

      lambda {
        GT::Framer.dupe_frame!(@f1, @u.id, @r2)
      }.should_not raise_error
    end

    it "should accept roll or roll_id" do
      lambda {
        GT::Framer.dupe_frame!(@f1, @u, @r2)
      }.should_not raise_error

      lambda {
        GT::Framer.dupe_frame!(@f1, @u, @r2.id)
      }.should_not raise_error
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

    it "should be a heavy_weight frame by default" do
      @f2 = GT::Framer.dupe_frame!(@f1, @u, @r2)

      @f2.frame_type.should == Frame::FRAME_TYPE[:heavy_weight]
    end

  end

  context "removing dupe of Frame from Roll" do
    before(:each) do
      @roll_creator = Factory.create( :user )
      @roll = Factory.create(:roll, :creator => @roll_creator)
      @roll.save

      @frame = Factory.create(:frame)

      @dupe = GT::Framer.dupe_frame!(@frame, @roll_creator, @roll)
    end

    it "should destroy the dupe of the Frame" do
      lambda {
        GT::Framer.remove_dupe_of_frame_from_roll!(@frame, @roll)
        Frame.find(@frame.id).should == @frame
        Frame.find(@dupe.id).roll_id.should == nil
      }.should change { @roll.frames.count } .by(-1)
    end

  end

  context "creating dashboard entries" do

    before(:each) do
      @roll_creator = Factory.create(:user)
      @roll = Factory.create(:roll, :creator => @roll_creator)
      @roll.save

      @frame = Factory.create(:frame, :creator => @roll_creator)
      @frame.video = @video = Factory.create(:video)
      @frame.save

      @observer = Factory.create(:user)
    end

    context "creating a single DashboardEntry" do

      it "should create a DashboardEntry when given a Frame, action and User" do
        d = nil
        lambda {
          d = GT::Framer.create_dashboard_entry(@frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], @observer)
        }.should change { DashboardEntry.count } .by 1

        d.size.should == 1
        d[0].persisted?.should == true
        d[0].frame.should == @frame
        d[0].src_frame.should be_nil
        d[0].src_frame_id.should be_nil
        d[0].src_video.should be_nil
        d[0].src_video_id.should be_nil
        d[0].friend_sharers_array.should == []
        d[0].friend_viewers_array.should == []
        d[0].friend_likers_array.should == []
        d[0].friend_rollers_array.should == []
        d[0].friend_complete_viewers_array.should == []
        d[0].video.should == @video
        d[0].actor.should == @roll_creator
        d[0].user.should == @observer
      end

      it "should set the DashboardEntry's src_frame when specified as an option" do
        src_frame = Factory.create(:frame)

        d = nil
        lambda {
          d = GT::Framer.create_dashboard_entry(@frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], @observer, {:src_frame_id => src_frame.id})
        }.should change { DashboardEntry.count } .by 1

        d.size.should == 1
        d[0].persisted?.should == true
        d[0].src_frame.should == src_frame
        d[0].src_frame_id.should == src_frame.id
      end

      it "should set the DashboardEntry's src_video when specified as an option" do
        src_video = Factory.create(:video)

        d = nil
        lambda {
          d = GT::Framer.create_dashboard_entry(@frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], @observer, {:src_video_id => src_video.id})
        }.should change { DashboardEntry.count } .by 1

        d.size.should == 1
        d[0].persisted?.should == true
        d[0].src_video.should == src_video
        d[0].src_video_id.should == src_video.id
      end

      it "should set the DashboardEntry's id when creation_time is specified as an option" do
        creation_time = 4.minutes.ago

        d = GT::Framer.create_dashboard_entry(@frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], @observer, {:creation_time => creation_time})

        d.size.should == 1
        d[0].id.generation_time.to_i.should == creation_time.to_i
      end

      it "should set the DashboardEntry's friend arrays when specified as options" do
        @friend_user = Factory.create(:user)
        @friend_user_id_string = @friend_user.id.to_s

        d = nil
        dbe_options = {
          :friend_sharers_array => [@friend_user_id_string],
          :friend_viewers_array => [@friend_user_id_string],
          :friend_likers_array => [@friend_user_id_string],
          :friend_rollers_array => [@friend_user_id_string],
          :friend_complete_viewers_array => [@friend_user_id_string]
        }
        lambda {
          d = GT::Framer.create_dashboard_entry(@frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], @observer, dbe_options)
        }.should change { DashboardEntry.count } .by 1

        d.size.should == 1
        d[0].persisted?.should == true
        d[0].friend_sharers_array.should == [@friend_user_id_string]
        d[0].friend_viewers_array.should == [@friend_user_id_string]
        d[0].friend_likers_array.should == [@friend_user_id_string]
        d[0].friend_rollers_array.should == [@friend_user_id_string]
        d[0].friend_complete_viewers_array.should == [@friend_user_id_string]
      end

      it "should not persist anything when persist option is set to false" do
        d = nil
        lambda {
          d = GT::Framer.create_dashboard_entry(@frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], @observer, {:persist => false})
        }.should_not change { DashboardEntry.count }

        # can't trust the persisted? method because of our internal use of from_mongo,
        # so verify that reloading causes an error as an alternate way of checking that this dbe is not persisted
        expect{d[0].reload}.to raise_error
      end

      it "works without a frame" do
        followed_user = Factory.create(:user)
        following_user = Factory.create(:user)

        expect {
          @res = GT::Framer.create_dashboard_entry(nil, DashboardEntry::ENTRY_TYPE[:follow_notification], followed_user, {:actor_id => following_user.id})
        }.to change(DashboardEntry, :count).by(1)

        dbe = @res[0]
        expect(dbe.frame_id).to be_nil
        expect(dbe.roll_id).to be_nil
        expect(dbe.video_id).to be_nil
        expect(dbe.user_id).to eql followed_user.id
        expect(dbe.actor_id).to eql following_user.id
        expect(dbe.action).to eql DashboardEntry::ENTRY_TYPE[:follow_notification]
      end

      it "raises an error when neither a frame nor an actor are specified" do
        user = Factory.create(:user)

        expect {
          GT::Framer.create_dashboard_entry(nil, DashboardEntry::ENTRY_TYPE[:follow_notification], user)
        }.to raise_error(ArgumentError, 'must supply a Frame, an Actor, or both')
      end
    end

    context "creating mutiple DashboardEntries" do
      before(:each) do
        @roll_creator = Factory.create(:user)
        @roll = Factory.create(:roll, :creator => @roll_creator)
        @roll.save

        @frame1 = Factory.create(:frame, :creator => @roll_creator)
        @frame1.video = @video = Factory.create(:video)
        @frame1.save

        @frame2 = Factory.create(:frame, :creator => @roll_creator)
        @frame2.video = @video = Factory.create(:video)
        @frame2.save

        @observer = Factory.create(:user)
      end

      it "sets the dashboard entries' actor_id based on the :actor_id option if it is passed in" do
        liking_user = Factory.create(:user)

        # accepts a BSON::ObjectId
        res = GT::Framer.create_dashboard_entries([@frame1], DashboardEntry::ENTRY_TYPE[:like_notification], [@observer.id], {:actor_id => liking_user.id, :return_dbe_models => true})
        expect(res[0].actor_id).to eql liking_user.id

        # accepts a String
        res = GT::Framer.create_dashboard_entries([@frame1], DashboardEntry::ENTRY_TYPE[:like_notification], [@observer.id], {:actor_id => liking_user.id.to_s, :return_dbe_models => true})
        expect(res[0].actor_id).to eql liking_user.id
      end

      it "works without a frame" do
        followed_user = Factory.create(:user)
        following_user = Factory.create(:user)

        expect {
          @res = GT::Framer.create_dashboard_entries([nil], DashboardEntry::ENTRY_TYPE[:follow_notification], [followed_user.id], {:actor_id => following_user.id, :return_dbe_models => true})
        }.to change(DashboardEntry, :count).by(1)

        dbe = @res[0]
        expect(dbe.frame_id).to be_nil
        expect(dbe.roll_id).to be_nil
        expect(dbe.video_id).to be_nil
        expect(dbe.user_id).to eql followed_user.id
        expect(dbe.actor_id).to eql following_user.id
        expect(dbe.action).to eql DashboardEntry::ENTRY_TYPE[:follow_notification]
      end

      it "raises an error when neither a frame nor an actor are specified" do
        followed_user = Factory.create(:user)

        expect {
          GT::Framer.create_dashboard_entries([nil], DashboardEntry::ENTRY_TYPE[:follow_notification], [followed_user.id])
        }.to raise_error(ArgumentError, 'must supply a Frame, an Actor, or both')
      end

      context "persistence" do
        before(:each) do
          @collection = double(:collection)
          DashboardEntry.stub(:collection).and_return(@collection)
        end

        it "persists using a single insert" do
          @collection.should_receive(:insert).once
          GT::Framer.create_dashboard_entries([@frame1, @frame2], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id])
        end

        it "does not persist if the persist option is set to false" do
          @collection.should_not_receive(:insert)
          GT::Framer.create_dashboard_entries([@frame1, @frame2], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id], {:persist => false})
        end

        it "does not persist if no dbes are succesfully initialized" do
          @collection.should_not_receive(:insert)
          GT::Framer.create_dashboard_entries([], DashboardEntry::ENTRY_TYPE[:new_social_frame], [])
        end
      end
    end

    context "asynchronous" do
      before(:each) do
        ResqueSpec.reset!
      end

      it "adds a DashboardEntryCreator job to the queue" do
        GT::Framer.create_dashboard_entries_async([@frame], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id])
        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued([@frame.id], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id], {:persist => true})
      end

      it "does nothing if no user ids are passed" do
        GT::Framer.create_dashboard_entries_async([@frame], DashboardEntry::ENTRY_TYPE[:new_social_frame], [])
        DashboardEntryCreator.should have_queue_size_of(0)
      end
    end
  end

  context "backfilling DashboardEntries" do
    before(:each) do
      @roll_creator = Factory.create(:user)
      @roll = Factory.create(:roll, :creator => @roll_creator)

      @frame3 = Factory.create(:frame, :roll => @roll, :score => 10, :_id => BSON::ObjectId.from_time(1.week.ago, :unique => true))
      @frame2 = Factory.create(:frame, :roll => @roll, :score => 11, :_id => BSON::ObjectId.from_time(2.days.ago, :unique => true))
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

    it "creates 2 new DashboardEntries" do
      lambda {
        res = GT::Framer.backfill_dashboard_entries(@user, @roll, 2)
      }.should change { DashboardEntry.count } .by 2
    end

    it "gives the new DashboardEntries valid attributes" do
      GT::Framer.backfill_dashboard_entries(@user, @roll, 2)
      MongoMapper::Plugins::IdentityMap.clear
      @user.dashboard_entries[0].frame_id.should == @frame0.id
      @user.dashboard_entries[1].frame_id.should == @frame1.id
    end

    it "should backfill User's dashboard with 2 frames in the correct order" do
      GT::Framer.backfill_dashboard_entries(@user, @roll, 2)
      @user.dashboard_entries.count.should == 2
      @user.dashboard_entries[0].frame.should == @frame0
      @user.dashboard_entries[1].frame.should == @frame1
    end

    it "should give the new DashboardEntries backdated id's" do
      GT::Framer.backfill_dashboard_entries(@user, @roll, 4)
      @user.dashboard_entries[0].created_at.should == @frame0.created_at
      @user.dashboard_entries[1].created_at.should == @frame1.created_at
      @user.dashboard_entries[2].created_at.should == @frame2.created_at
      @user.dashboard_entries[3].created_at.should == @frame3.created_at
    end

    it "should backfill even if there aren't enough Frames" do
      lambda {
        res = GT::Framer.backfill_dashboard_entries(@user, @roll, 20)
      }.should change { @user.dashboard_entries.count } .by 4
    end

    it "shouldn't die if there aren't any frames" do
      empty_roll = Factory.create(:roll, :creator => @roll_creator )

      lambda {
        res = GT::Framer.backfill_dashboard_entries(@user, empty_roll, 20)
      }.should change { @user.dashboard_entries.count } .by 0
    end

    it "doesn't call the asynchronous creation method by default" do
      GT::Framer.should_not_receive(:create_dashboard_entries_async)

      GT::Framer.backfill_dashboard_entries(@user, @roll, 2)
    end

    context "asynchronous" do
      before(:each) do
        ResqueSpec.reset!
      end

      it "adds a DashboardEntryCreator job to the queue" do
        MongoMapper::Plugins::IdentityMap.clear
        GT::Framer.should_receive(:create_dashboard_entries_async).with([@frame1, @frame0], DashboardEntry::ENTRY_TYPE[:new_in_app_frame], [@user.id], {:backdate => true})

        GT::Framer.backfill_dashboard_entries(@user, @roll, 2, {:async_dashboard_entries => true})
      end

      it "backfills the User's dashboard with frames asynchronously" do
        MongoMapper::Plugins::IdentityMap.clear

        expect {
          @res = GT::Framer.backfill_dashboard_entries(@user, @roll, 2, {:async_dashboard_entries => true})
        }.not_to change { DashboardEntry.count }

        @res.should be_nil
        @user.reload
        @user.dashboard_entries.length.should == 0

        expect { ResqueSpec.perform_next(:dashboard_entries_queue) }.to change { DashboardEntry.count }.by 2

        @user.reload
        dbes = @user.dashboard_entries
        dbes.length.should == 2
        dbes[0].frame_id.should == @frame0.id
        dbes[1].frame_id.should == @frame1.id
        dbes[0].created_at.should == @frame0.created_at
        dbes[1].created_at.should == @frame1.created_at
      end

    end
  end

end
