require 'spec_helper'
 
describe NotificationMailer do
  describe 'comment notifications' do
    before(:all) do
      @user_to = Factory.create(:user)
      @user_from = Factory.create(:user)
      @comment = "how much would a wood chuck chuck..."
      @message = Factory.create(:message, :text => @comment, :user => @user_to)
      @conversation = Factory.create(:conversation, :messages => [@message])
      @video = Factory.create(:video, :title => 'tit')
      @frame = Factory.create(:frame, :roll=> Factory.create(:roll, :creator => @user_to), :video => @video)
      @email = NotificationMailer.comment_notification(@user_to, @user_from, @frame, @message)
    end
 
    it 'renders the subject' do
      @email.subject.should == Settings::Email.comment_notification['subject'] % {:commenters_name => @user_from.nickname, :video_title => "tit"}
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
      @video = Factory.create(:video, :title => 'ti')
      @roll = Factory.create(:roll, :creator => @user_to)
      @frame = Factory.create(:frame, :video => @video, :roll => @roll)
      @email = NotificationMailer.upvote_notification(@user_to, @user_from, @frame)
    end
 
    it 'renders the subject' do
      @email.subject.should eq(Settings::Email.upvote_notification['subject'] % {:upvoters_name => @user_from.nickname, :video_title => 'ti' } )
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
      @video = Factory.create(:video, :title => 'tit')
      @old_frame = Factory.create(:frame, :creator => @old_user, :video => @video, :roll => @old_roll)
      @new_frame = Factory.create(:frame, :creator => @new_user, :video => @video, :roll => @new_roll)
      @email = NotificationMailer.reroll_notification(@old_frame, @new_frame)
    end
 
    it 'renders the subject' do
      @email.subject.should eq(Settings::Email.reroll_notification['subject'] % {:re_rollers_name => @new_user.nickname, :video_title => 'tit'})
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

  describe 'join roll notifications' do
    before(:all) do
      @user_joined = Factory.create(:user, :name => "dan")
      @roll_owner = Factory.create(:user)
      @roll = Factory.create(:roll, :creator => @roll_owner, :public => false, :title => "tit")
      @video = Factory.create(:video)
      @email = NotificationMailer.join_roll_notification(@roll_owner, @user_joined, @roll)
    end
 
    it 'renders the subject' do
      subj = Settings::Email.join_roll_notification['subject'] % {:users_name =>"dan", :roll_title => "tit"}
      @email.subject.should eq(subj)
    end
    
    it 'renders the receiver email' do
      @email.to.should eq([@roll_owner.primary_email])
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