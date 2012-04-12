require 'spec_helper'

require 'notification_manager'

describe GT::NotificationManager do

  describe "upvote notifications" do
    before(:all) do
      @user = Factory.create(:user)
      @frame = Factory.create(:frame)
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
      @comment = "how much would a wood chuck chuck..."
      @conversation = Factory.create(:conversation, :messages => [Factory.create(:message, :text => @comment, :user => @user)])      
    end
    
    it "should should queue email to deliver" do
      lambda {
        GT::NotificationManager.check_and_send_comment_notification(@user, @conversation)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end
    
    it "should return nil if first message in a conv is from a faux user" do
      @conversation.messages.first.user = nil; @conversation.save
      r = GT::NotificationManager.check_and_send_comment_notification(@user, @conversation)
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

end