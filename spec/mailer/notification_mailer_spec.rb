require 'spec_helper'
 
describe NotificationMailer do
  describe 'comment notifications' do
    before(:all) do
      @user_to = Factory.create(:user, :primary_email => 'your@mom.com')
      @user_from = Factory.create(:user, :primary_email => 'my@mom.com')
      @comment = "how much would a wood chuck chuck..."
      @conversation = Factory.create(:conversation, :messages => [Factory.create(:message, :text => @comment)])
      @email = NotificationMailer.comment_notification(@user_to, @user_from, @conversation)
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
      @frame = Factory.create(:frame)
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
end