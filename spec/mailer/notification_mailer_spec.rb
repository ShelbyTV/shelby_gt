require 'spec_helper'
 
describe NotificationMailer do
  describe 'comment notifications' do
    before(:all) do
      @user_to = Factory.create(:user, :primary_email => 'your@mom.com')
      @user_from = Factory.create(:user, :primary_email => 'my@mom.com')
      @comment = "how much would a wood chuck chuck..."
      @message = Factory.create(:message, :text => @comment, :user => @user_to)
      @conversation = Factory.create(:conversation, :messages => [@message])
      @video = Factory.create(:video)
      @frame = Factory.create(:frame, :roll=> Factory.create(:roll, :creator => @user_to), :video => @video)
      @email = NotificationMailer.comment_notification(@user_to, @user_from, @frame, @message)
    end
 
    it 'renders the subject' do
      @email.subject.should eq(Settings::Email.comment_notification['subject'])
    end
    
    it 'renders the receiver email' do
      @email.to.should eq([@user_to.primary_email])
    end
    
    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end
    
    #ensure that the an instance var is assigned properly, eg @confirmation_url variable appears in the email body
    #it 'assigns @confirmation_url' do
    #  mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    #end
  end
  
  describe 'upvote notifications' do
    before(:all) do
      @user_to = Factory.create(:user, :primary_email => 'your@mom.com')
      @user_from = Factory.create(:user, :primary_email => 'my@mom.com')
      @video = Factory.create(:video)
      @roll = Factory.create(:roll, :creator => @user_to)
      @frame = Factory.create(:frame, :video => @video, :roll => @roll)
      @email = NotificationMailer.upvote_notification(@user_to, @user_from, @frame)
    end
 
    it 'renders the subject' do
      @email.subject.should eq(Settings::Email.upvote_notification['subject'])
    end
    
    it 'renders the receiver email' do
      @email.to.should eq([@user_to.primary_email])
    end
    
    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end
    
    #ensure that the an instance var is assigned properly, eg @confirmation_url variable appears in the email body
    #it 'assigns @confirmation_url' do
    #  mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    #end
  end
  
  describe 'reroll notifications' do
    before(:all) do
      @old_user = Factory.create(:user)
      @new_user = Factory.create(:user)
      @old_roll = Factory.create(:roll, :creator => @old_user)
      @new_roll = Factory.create(:roll, :creator => @new_user)
      @video = Factory.create(:video)
      @old_frame = Factory.create(:frame, :creator => @old_user, :video => @video, :roll => @old_roll)
      @new_frame = Factory.create(:frame, :creator => @new_user, :video => @video, :roll => @new_roll)
      @email = NotificationMailer.reroll_notification(@old_frame, @new_frame)
    end
 
    it 'renders the subject' do
      @email.subject.should eq(Settings::Email.reroll_notification['subject'])
    end
    
    it 'renders the receiver email' do
      @email.to.should eq([@old_user.primary_email])
    end
    
    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end
    
    #ensure that the an instance var is assigned properly, eg @confirmation_url variable appears in the email body
    #it 'assigns @confirmation_url' do
    #  mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    #end
  end
end