require 'spec_helper'

require 'notification_manager'
require 'open_graph'

describe GT::NotificationManager do


  context "invisble character hack stubbed" do

    before(:each) do
      GT::NotificationManager.stub(:insert_invisible_character_at_random_position) do |message|
        message
      end
    end

    describe "upvote notifications" do
      before(:each) do
        @user = Factory.create(:user)
        @roll = Factory.create(:roll, :creator => @user)
        @f_creator = Factory.create(:user, :gt_enabled => true)
        @frame = Factory.create(:frame, :creator => @f_creator,  :video=>Factory.create(:video), :roll => @roll)
      end

      it "should not send email to any non-gt_enabled users" do
        @f_creator = Factory.create(:user, :gt_enabled => false)
        @frame = Factory.create(:frame, :creator => @f_creator,  :video=>Factory.create(:video), :roll => @roll)
        lambda {
          GT::NotificationManager.check_and_send_upvote_notification(@user, @frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should should queue email to deliver" do
        lambda {
          GT::NotificationManager.check_and_send_upvote_notification(@user, @frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should return nil if user is creator of the frame" do
        @frame.creator = @user; @frame.save
        r = GT::NotificationManager.check_and_send_upvote_notification(@user, @frame)
        r.should eq(nil)
      end

      it "should raise error with bad frame or user" do
        lambda {
          GT::NotificationManager.check_and_send_upvote_notification(@user)
        }.should raise_error(ArgumentError)

        lambda {
          GT::NotificationManager.check_and_send_upvote_notification(@frame, @frame)
        }.should raise_error(ArgumentError)
      end
    end

    describe "like notifications" do
      before(:each) do
        @user = Factory.create(:user)
        @f_creator = Factory.create(:user, :gt_enabled => true)
        @roll = Factory.create(:roll, :creator => @f_creator)
        @video = Factory.create(:video)
        @frame = Factory.create(:frame, :creator => @f_creator, :video=> @video, :roll => @roll)
      end

      it "should queue email to deliver" do
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@frame, @user)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not send email to user with like_notifications disabled" do
        @f_creator.preferences.like_notifications = false
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@frame, @user)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not send email to user with no email address" do
        @f_creator.primary_email = nil
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@frame, @user)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not send email if user is creator of the frame" do
        @frame.creator = @user
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@frame, @user)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "creates a like_notification dbe for the frame creator when destinations includes :notification_center" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, @user, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@frame.id],
          DashboardEntry::ENTRY_TYPE[:like_notification],
          [@f_creator.id],
          {:persist => true, :actor_id => @user.id}
        )
        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)
        AppleNotificationPusher.should have_queue_size_of(0)

        dbe = DashboardEntry.last
        expect(dbe.user).to eql @f_creator
        expect(dbe.actor).to eql @user
        expect(dbe.action).to eql DashboardEntry::ENTRY_TYPE[:like_notification]
        expect(dbe.frame).to eql @frame
        expect(dbe.video).to eql @video
      end

      it "creates a like_notification dbe and queues up a push notification if user is eligible" do
        @f_creator.apn_tokens = ['token']
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, @user, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@frame.id],
          DashboardEntry::ENTRY_TYPE[:like_notification],
          [@f_creator.id],
          {
            :persist => true,
            :actor_id => @user.id,
            :push_notification_options => {
              :devices => ['token'],
              :alert => "#{@user.name} liked your video",
              :ga_event => {
                :category => "Push Notification",
                :action => "Send Like Notification",
                :label => @f_creator.id
              }
            }
          }
        )
        AppleNotificationPusher.should have_queue_size_of(0)

        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)

        AppleNotificationPusher.should have_queue_size_of(1)
        AppleNotificationPusher.should have_queued({
          :device => 'token',
          :alert => "#{@user.name} liked your video",
          :sound => 'default',
          :dashboard_entry_id => DashboardEntry.last.id,
          :ga_event => {
            :category => "Push Notification",
            :action => "Send Like Notification",
            :label => @f_creator.id.to_s
          }
        })
      end

      it "inserts a random invisible space in the push notification message" do
        @f_creator.apn_tokens = ['token']
        ResqueSpec.reset!
        GT::NotificationManager.should_receive(:insert_invisible_character_at_random_position).with("#{@user.name} liked your video")

        GT::NotificationManager.check_and_send_like_notification(@frame, @user, [:notification_center])
      end

      it "does not push a like notification to iOS if user has that preference turned off" do
        @f_creator.apn_tokens = ['token']
        @f_creator.preferences.like_notifications_ios = false
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, @user, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@frame.id],
          DashboardEntry::ENTRY_TYPE[:like_notification],
          [@f_creator.id],
          { :persist => true, :actor_id => @user.id }
        )

        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)

        AppleNotificationPusher.should have_queue_size_of(0)
      end

      it "creates an anonymous_like_notification dbe when there is no user_from" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, nil, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@frame.id],
          DashboardEntry::ENTRY_TYPE[:anonymous_like_notification],
          [@f_creator.id],
          {:persist => true, :actor_id => nil}
        )
        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)
        AppleNotificationPusher.should have_queue_size_of(0)

        dbe = DashboardEntry.last
        expect(dbe.user).to eql @f_creator
        expect(dbe.actor).to be_nil
        expect(dbe.action).to eql DashboardEntry::ENTRY_TYPE[:anonymous_like_notification]
        expect(dbe.frame).to eql @frame
        expect(dbe.video).to eql @video
      end

      it "creates an anonymous_like_notification dbe and queues up a push notification if user is eligible" do
        @f_creator.apn_tokens = ['token']
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, nil, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@frame.id],
          DashboardEntry::ENTRY_TYPE[:anonymous_like_notification],
          [@f_creator.id],
          {
            :persist => true,
            :actor_id => nil,
            :push_notification_options => {
              :devices => ['token'],
              :alert => "Someone liked your video",
              :ga_event => {
                :category => "Push Notification",
                :action => "Send Like Notification",
                :label => @f_creator.id
              }
            }
          }
        )
        AppleNotificationPusher.should have_queue_size_of(0)

        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)

        AppleNotificationPusher.should have_queue_size_of(1)
        AppleNotificationPusher.should have_queued({
          :device => 'token',
          :alert => "Someone liked your video",
          :sound => 'default',
          :dashboard_entry_id => DashboardEntry.last.id,
          :ga_event => {
            :category => "Push Notification",
            :action => "Send Like Notification",
            :label => @f_creator.id.to_s
          }
        })
      end

      it "creates an anonymous_like_notification dbe if the liking user's user_type is anonymous" do
        @user.user_type = User::USER_TYPE[:anonymous]
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, @user, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@frame.id],
          DashboardEntry::ENTRY_TYPE[:anonymous_like_notification],
          [@f_creator.id],
          {:persist => true, :actor_id => nil}
        )
      end

      it "creates an anonymous_like_notification dbe and queues up a push notification if user is eligible and liking user's user_type is anonymous" do
        @f_creator.apn_tokens = ['token']
        @user.user_type = User::USER_TYPE[:anonymous]
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, @user, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@frame.id],
          DashboardEntry::ENTRY_TYPE[:anonymous_like_notification],
          [@f_creator.id],
          {
            :persist => true,
            :actor_id => nil,
            :push_notification_options => {
              :devices => ['token'],
              :alert => "Someone liked your video",
              :ga_event => {
                :category => "Push Notification",
                :action => "Send Like Notification",
                :label => @f_creator.id
              }
            }
          }
        )
      end

      it "inserts a random invisible space in the push notification message" do
        @f_creator.apn_tokens = ['token']
        ResqueSpec.reset!

        GT::NotificationManager.should_receive(:insert_invisible_character_at_random_position).with("Someone liked your video")

        GT::NotificationManager.check_and_send_like_notification(@frame, nil, [:notification_center])
      end

      it "does not push an anonymous_like notification to iOS if user has that preference turned off" do
        @f_creator.apn_tokens = ['token']
        @f_creator.preferences.like_notifications_ios = false
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, nil, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@frame.id],
          DashboardEntry::ENTRY_TYPE[:anonymous_like_notification],
          [@f_creator.id],
          {:persist => true, :actor_id => nil}
        )

        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)

        AppleNotificationPusher.should have_queue_size_of(0)
      end

      it "doesn't create a notification dbe for the frame creator when destinations doesn't include :notification_center" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, @user)
        GT::NotificationManager.check_and_send_like_notification(@frame, nil)

        DashboardEntryCreator.should have_queue_size_of(0)
      end

      it "doesn't create a like_notification dbe when user_from and user_to are the same" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_like_notification(@frame, @f_creator, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(0)
      end

      it "should raise error with bad frame" do
        lambda {
          GT::NotificationManager.check_and_send_like_notification(@user)
        }.should raise_error(ArgumentError)
      end
    end

    describe "conversation notifications" do
      before(:each) do
        @frame_creator = Factory.create(:user)
        @roll_creator = Factory.create(:user)
        @user2 = Factory.create(:user)

        @roll = Factory.create(:roll, :creator => @roll_creator)
        @roll.add_follower(@roll_creator)

        @message = Factory.create(:message, :text => "foo", :user => @user2)
        @conversation = Factory.create(:conversation, :messages => [@message])
        @frame = Factory.create(:frame,
          :creator => @frame_creator,
          :roll=> @roll,
          :video => Factory.create(:video),
          :conversation => @conversation)
        @conversation.frame = @frame
        @conversation.save
      end

      it "should raise error with bad frame or user" do
        lambda {
          GT::NotificationManager.send_new_message_notifications(@user)
        }.should raise_error(ArgumentError)

        lambda {
          GT::NotificationManager.send_new_message_notifications(@conversation)
        }.should raise_error(ArgumentError)
      end

      it "should email Frame creator even if they didn't post a message" do
        lambda {
          GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should send notifications even if Frame is from a faux User" do
        @frame_creator.user_type = User::USER_TYPE[:faux]
        @frame_creator.save

        lambda {
          GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should send emails to other Message creators" do
        #will email these two as well as frame creator
        @conversation.messages << Factory.create(:message, :text => "d", :user => Factory.create(:user))
        @conversation.messages << Factory.create(:message, :text => "s", :user => Factory.create(:user))

        lambda {
          GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not email somebody w/o a primary_email" do
        #won't email this guy b/c no email
        @conversation.messages << Factory.create(:message, :text => "s", :user => Factory.create(:user, :primary_email => nil))

        lambda {
          GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not email somebody w/ preferences set nto to send comment notifications" do
        #won't email this guy b/c of preferences
        u = Factory.create(:user)
        u.preferences.comment_notifications = false
        u.save
        @conversation.messages << Factory.create(:message, :text => "s", :user => u)

        lambda {
          GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should email all members of a private roll when there's a new comment (even if they haven't participated in this convo)" do
        @roll.public = false
        @roll.save
        @roll.add_follower(Factory.create(:user))
        @roll.add_follower(Factory.create(:user))

        lambda {
          GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

    end

    describe "comment notifications" do
      before(:each) do
        @frame_creator = Factory.create(:user)

        @frame = Factory.create(:frame,
          :creator => @frame_creator,
          :video => Factory.create(:video))
      end

      it "should raise error with bad frame or type" do
        lambda {
          GT::NotificationManager.check_and_send_comment_notification(@frame_creator)
        }.should raise_error(ArgumentError)
      end

      it "should not send email if user has chosen to not receive emails" do
        @frame_creator.preferences.comment_notifications = false
        @frame_creator.save
        lambda {
          GT::NotificationManager.check_and_send_comment_notification(@frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should email Frame creator even if they didn't post a message" do
        lambda {
          GT::NotificationManager.check_and_send_comment_notification(@frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end


    end

    describe "reroll notifications" do
      before(:each) do
        @old_user = Factory.create(:user, :gt_enabled => true)
        @new_user = Factory.create(:user, :gt_enabled => true)
        @old_roll = Factory.create(:roll, :creator => @old_user)
        @new_roll = Factory.create(:roll, :creator => @new_user)
        @video = Factory.create(:video)
        @old_frame = Factory.create(:frame, :creator => @old_user, :video => @video, :roll => @old_roll)
        @new_frame = Factory.create(:frame, :creator => @new_user, :video => @video, :roll => @new_roll)
      end

      it "should should queue email to deliver" do
        lambda {
          GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not send email to any non-gt_enabled users" do
        @old_user.gt_enabled = false; @old_user.save
        @old_frame = Factory.create(:frame, :creator => @old_user, :video => @video, :roll => @old_roll)
        lambda {
          GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not shit the bed if frames creator is nil" do
        @old_user.gt_enabled = false; @old_user.save
        @old_frame = Factory.create(:frame, :creator => nil, :video => @video, :roll => @old_roll)
        lambda {
          GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should return nil if user is creator of the frame" do
        @old_frame.creator = @new_user; @old_frame.save
        r = GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame)
        r.should eq(nil)
      end

      it "should raise error with bad frame or user" do
        lambda {
          GT::NotificationManager.check_and_send_reroll_notification(@old_frame)
        }.should raise_error(ArgumentError)
      end

      it "creates a share_notification dbe for the frame creator when destinations includes :notification_center" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@old_frame.id],
          DashboardEntry::ENTRY_TYPE[:share_notification],
          [@old_user.id],
          {:persist => true, :actor_id => @new_user.id}
        )
        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)
        AppleNotificationPusher.should have_queue_size_of(0)

        dbe = DashboardEntry.last
        expect(dbe.user).to eql @old_user
        expect(dbe.actor).to eql @new_user
        expect(dbe.action).to eql DashboardEntry::ENTRY_TYPE[:share_notification]
        expect(dbe.frame).to eql @old_frame
        expect(dbe.video).to eql @video
      end

      it "creates a share_notification dbe and queues up a push notification if user is eligible" do
        @old_user.apn_tokens = ['token']
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@old_frame.id],
          DashboardEntry::ENTRY_TYPE[:share_notification],
          [@old_user.id],
          {
            :persist => true,
            :actor_id => @new_user.id,
            :push_notification_options => {
              :devices => ['token'],
              :alert => "#{@new_user.name} shared your video",
              :ga_event => {
                :category => "Push Notification",
                :action => "Send Share Notification",
                :label => @old_user.id
              }
            }
          }
        )
        AppleNotificationPusher.should have_queue_size_of(0)

        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)

        AppleNotificationPusher.should have_queue_size_of(1)
        AppleNotificationPusher.should have_queued({
          :device => 'token',
          :alert => "#{@new_user.name} shared your video",
          :sound => 'default',
          :dashboard_entry_id => DashboardEntry.last.id,
          :ga_event => {
            :category => "Push Notification",
            :action => "Send Share Notification",
            :label => @old_user.id.to_s
          }
        })
      end

      it "inserts a random invisible space in the push notification message" do
        @old_user.apn_tokens = ['token']
        ResqueSpec.reset!

        GT::NotificationManager.should_receive(:insert_invisible_character_at_random_position).with("#{@new_user.name} shared your video")

        GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame, [:notification_center])
      end

      it "does not push a share notification to iOS if user has that preference turned off" do
        @old_user.apn_tokens = ['token']
        @old_user.preferences.reroll_notifications_ios = false
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [@old_frame.id],
          DashboardEntry::ENTRY_TYPE[:share_notification],
          [@old_user.id],
          {:persist => true, :actor_id => @new_user.id}
        )

        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)

        AppleNotificationPusher.should have_queue_size_of(0)
      end

      it "doesn't create a share_notification dbe for the frame creator when destinations doesn't include :notification_center" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame)

        DashboardEntryCreator.should have_queue_size_of(0)
      end

      it "doesn't create a share_notification dbe when user_from and user_to are the same" do
        @old_frame.creator = @new_user; @old_frame.save
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_reroll_notification(@old_frame, @new_frame, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(0)
      end

    end

    describe "join roll notifications" do
      before(:each) do
        @user_joined = Factory.create(:user)
        @roll_owner = Factory.create(:user, :gt_enabled => true, :user_image => "http://f.off.com.jpg")
        @roll = Factory.create(:roll, :creator => @roll_owner)
      end

      it "should not send email to any non-gt_enabled users" do
        u = Factory.create(:user, :gt_enabled => false)
        r = Factory.create(:roll, :creator => u)
        lambda {
          GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, r)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not shit the bed if roll's owner DNE" do
        r = Factory.create(:roll, :creator => nil)
        lambda {
          GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, r)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should should queue email to deliver" do
        lambda {
          GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "doesn't send email if the following user's user_type is anonymous" do
        @user_joined.user_type = User::USER_TYPE[:anonymous]

        expect {
          GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll)
        }.not_to change(ActionMailer::Base.deliveries,:size)
      end

      it "should return nil if user is creator of the roll" do
        @roll.creator = @user_joined; @roll.save
        r = GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll)
        r.should eq(nil)
      end

      it "should raise error with bad roll or user" do
        lambda {
          GT::NotificationManager.check_and_send_join_roll_notification(@user)
        }.should raise_error(ArgumentError)

        lambda {
          GT::NotificationManager.check_and_send_join_roll_notification(@roll)
        }.should raise_error(ArgumentError)
      end

      it "creates a follow_notification dbe for the roll owner when destinations includes :notification_center" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [nil],
          DashboardEntry::ENTRY_TYPE[:follow_notification],
          [@roll_owner.id],
          {:persist => true, :actor_id => @user_joined.id}
        )
        AppleNotificationPusher.should have_queue_size_of(0)

        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)

        dbe = DashboardEntry.last
        expect(dbe.user).to eql @roll_owner
        expect(dbe.actor).to eql @user_joined
        expect(dbe.action).to eql DashboardEntry::ENTRY_TYPE[:follow_notification]
        expect(dbe.frame).to be_nil
      end

      it "queues up a push notification if user is eligible" do
        @roll_owner.apn_tokens = ['token']
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll, [:notification_center])

        AppleNotificationPusher.should have_queue_size_of(1)
        AppleNotificationPusher.should have_queued({
          :device => 'token',
          :alert => "#{@user_joined.name} is following you",
          :sound => 'default',
          :user_id => @user_joined.id,
          :ga_event => {
            :category => "Push Notification",
            :action => "Send Follow Notification",
            :label => @roll_owner.id
          }
        })
      end

      it "inserts a random invisible space in the push notification message" do
        @roll_owner.apn_tokens = ['token']
        ResqueSpec.reset!

        GT::NotificationManager.should_receive(:insert_invisible_character_at_random_position).with("#{@user_joined.name} is following you")

        GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll, [:notification_center])
      end

      it "does not push a share notification to iOS if user has that preference turned off" do
        @roll_owner.apn_tokens = ['token']
        @roll_owner.preferences.roll_activity_notifications_ios = false
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll, [:notification_center])

        AppleNotificationPusher.should have_queue_size_of(0)
      end

      it "does not create a follow_notification dbe for the roll owner when following user's user_type is anonymous" do
        @user_joined.user_type = User::USER_TYPE[:anonymous]
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(0)
      end

      it "does not queue up a push notification when following user's user_type is anonymous" do
        @roll_owner.apn_tokens = ['token']
        @user_joined.user_type = User::USER_TYPE[:anonymous]
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll, [:notification_center])

        AppleNotificationPusher.should have_queue_size_of(0)
      end

      it "doesn't create a follow_notification dbe for the roll owner when destinations does not include :notification_center" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_join_roll_notification(@user_joined, @roll)

        DashboardEntryCreator.should have_queue_size_of(0)
      end

      it "doesn't create a follow_notification dbe when user_from and user_to are the same" do
        ResqueSpec.reset!

        GT::NotificationManager.check_and_send_join_roll_notification(@roll_owner, @roll, [:notification_center])

        DashboardEntryCreator.should have_queue_size_of(0)
      end

    end

    describe "invite accepted notifications" do
      before(:each) do
        @invitee_roll = Factory.create(:roll, :creator => @invitee)
        @invitee = Factory.create(:user, :public_roll => @invitee_roll)
        @inviter = Factory.create(:user)
      end

      it "should queue email to deliver" do
        lambda {
          GT::NotificationManager.check_and_send_invite_accepted_notification(@inviter, @invitee)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not queue email to deliver if the inviter has disabled it via preferences" do
        @inviter.preferences.invite_accepted_notifications = false
        lambda {
          GT::NotificationManager.check_and_send_invite_accepted_notification(@inviter, @invitee)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should not queue email to deliver if the inviter has no email address" do
        @inviter.primary_email = nil
        lambda {
          GT::NotificationManager.check_and_send_invite_accepted_notification(@inviter, @invitee)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "should raise error with bad inviter or invitee" do
        lambda {
          GT::NotificationManager.check_and_send_join_roll_notification(@inviter, nil)
        }.should raise_error(ArgumentError)

        lambda {
          GT::NotificationManager.check_and_send_join_roll_notification(nil, @invitee)
        }.should raise_error(ArgumentError)
      end
    end

    describe "weekly email notification" do
      before(:each) do
        @user = Factory.create(:user)
        @sharer = Factory.create(:user)
        @video = Factory.create(:video)
        @frame = Factory.create(:frame, :creator => @sharer, :video => @video)
        @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation], :frame => @frame, :video => @video)
      end

      it "should queue email to deliver" do
        lambda {
          GT::NotificationManager.send_weekly_recommendation(@user, [@dbe])
        }.should change(ActionMailer::Base.deliveries,:size).by(1)
      end

      it "should pass through the right parameters to the mailer" do
        NotificationMailer.should_receive(:weekly_recommendation).with(@user, [@dbe], nil).and_call_original

        GT::NotificationManager.send_weekly_recommendation(@user, [@dbe])
      end
    end

  end

  describe "insert_invisible_character_at_random_position" do
    it "inserts an invible character at a random place in the string" do
      message = "Here's a message"
      new_message = GT::NotificationManager.insert_invisible_character_at_random_position(message)

      expect(new_message).not_to eql message
      expect(new_message.count("\u200C")).to eql 1
      expect(new_message.length).to eql(message.length + 1)

      new_message.slice!("\u200C")
      expect(new_message).to eql message
    end
  end

end
