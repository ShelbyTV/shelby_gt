require 'spec_helper'

require 'notification_manager'
require 'open_graph'

describe GT::NotificationManager do

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
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
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
      @frame = Factory.create(:frame, :creator => @f_creator,  :video=>Factory.create(:video), :roll => @roll)
    end

    it "should queue email to deliver" do
      lambda {
        GT::NotificationManager.check_and_send_like_notification(@frame, @user)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
      lambda {
        GT::NotificationManager.check_and_send_like_notification(@frame)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end

    it "should not send email to any non-gt_enabled users" do
      @f_creator.gt_enabled = false
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
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
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
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end

    it "should send notifications even if Frame is from a faux User" do
      @frame_creator.user_type = User::USER_TYPE[:faux]
      @frame_creator.save

      lambda {
        GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end

    it "should send emails to other Message creators" do
      #will email these two as well as frame creator
      @conversation.messages << Factory.create(:message, :text => "d", :user => Factory.create(:user))
      @conversation.messages << Factory.create(:message, :text => "s", :user => Factory.create(:user))

      lambda {
        GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
      }.should change(ActionMailer::Base.deliveries,:size).by(3)
    end

    it "should not email somebody w/o a primary_email" do
      #won't email this guy b/c no email
      @conversation.messages << Factory.create(:message, :text => "s", :user => Factory.create(:user, :primary_email => nil))

      lambda {
        GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end

    it "should not email somebody w/ preferences set nto to send comment notifications" do
      #won't email this guy b/c of preferences
      u = Factory.create(:user)
      u.preferences.comment_notifications = false
      u.save
      @conversation.messages << Factory.create(:message, :text => "s", :user => u)

      lambda {
        GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end

    it "should email all members of a private roll when there's a new comment (even if they haven't participated in this convo)" do
      @roll.public = false
      @roll.save
      @roll.add_follower(Factory.create(:user))
      @roll.add_follower(Factory.create(:user))

      lambda {
        GT::NotificationManager.send_new_message_notifications(@conversation, @message, @user2)
      }.should change(ActionMailer::Base.deliveries,:size).by(3)
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
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
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
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
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
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
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
      @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:channel_recommednation], :frame => @frame, :video => @video)
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