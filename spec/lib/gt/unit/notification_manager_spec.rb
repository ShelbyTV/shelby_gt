require 'spec_helper'

require 'notification_manager'

describe GT::NotificationManager do

  describe "upvote notifications" do
    before(:all) do
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

  describe "conversation notifications" do
    before(:all) do
      @frame_creator = Factory.create(:user)
      @roll_creator = Factory.create(:user)
      @user2 = Factory.create(:user)
      
      @message = Factory.create(:message, :text => "foo", :user => @user2)
      @conversation = Factory.create(:conversation, :messages => [@message])      
      @frame = Factory.create(:frame, 
        :creator => @frame_creator,
        :roll=> Factory.create(:roll, :creator => @roll_creator), 
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
        GT::NotificationManager.send_new_message_notifications(@conversation, @message)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end
    
    it "should send notifications even if Frame is from a faux User" do
      @frame_creator.faux = User::FAUX_STATUS[:true]
      @frame_creator.save
      
      lambda {
        GT::NotificationManager.send_new_message_notifications(@conversation, @message)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end
    
    it "should send emails to other Message creators" do
      #will email these two as well as frame creator
      @conversation.messages << Factory.create(:message, :text => "d", :user => Factory.create(:user))
      @conversation.messages << Factory.create(:message, :text => "s", :user => Factory.create(:user))
      
      #won't email this guy
      @conversation.messages << Factory.create(:message, :text => "s", :user => Factory.create(:user, :primary_email => nil))
      
      lambda {
        GT::NotificationManager.send_new_message_notifications(@conversation, @message)
      }.should change(ActionMailer::Base.deliveries,:size).by(3)
    end
    
  end

  describe "reroll notifications" do
    before(:all) do
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

end