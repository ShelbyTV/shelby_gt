require 'spec_helper'

require 'notification_manager'

describe GT::NotificationManager do

  describe "upvote notifications" do
    before(:all) do
      @user = Factory.create(:user)
      @roll = Factory.create(:roll, :creator => @user)
      @frame = Factory.create(:frame, :creator => Factory.create(:user),  :video=>Factory.create(:video), :roll => @roll)
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
      @user = Factory.create(:user)
      @user2 = Factory.create(:user)
      @comment = "how much would a wood chuck chuck..."
      @message = Factory.create(:message, :text => @comment, :user => @user2)
      @video = Factory.create(:video)
      @conversation = Factory.create(:conversation, :messages => [@message])      
      @frame = Factory.create(:frame, :roll=> Factory.create(:roll, :creator => @user), :video => @video, :conversation => @conversation)
    end
    
    it "should should queue email to deliver" do
      lambda {
        GT::NotificationManager.check_and_send_comment_notification(@conversation, @message)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end
    
    it "should return nil if first message in a conv is from a faux user" do
      @conversation.messages.first.user = nil; @conversation.save
      r = GT::NotificationManager.check_and_send_comment_notification(@conversation, @message)
      r.should eq(nil)
    end
    
    it "should raise error with bad frame or user" do
      lambda {
        GT::NotificationManager.check_and_send_comment_notification(@user) 
      }.should raise_error(ArgumentError)
      
      lambda { 
        GT::NotificationManager.check_and_send_comment_notification(@conversation) 
      }.should raise_error(ArgumentError)
    end
  end

  describe "reroll notifications" do
    before(:all) do
      @old_user = Factory.create(:user)
      @new_user = Factory.create(:user)
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