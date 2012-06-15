require 'spec_helper'
 
describe SharingMailer do
  describe 'share frame' do
    before(:each) do
      @from_user = Factory.create(:user, :primary_email => 'your@mom.com', :name => "dan")
      @to_email = 'your@dad.com'
      @message = "wassssuuuup!"
      video = Factory.create(:video, :thumbnail_url => "http://url.com/123.jpg", :title=>"blah")
      roll = Factory.create(:roll, :creator => @from_user)
      @roll_title = roll.title
      @frame = Factory.create(:frame, :creator_id => @from_user.id, :video_id => video.id, :roll => roll)
      @email = SharingMailer.share_frame(@from_user, @from_user.primary_email, @to_email, @message, @frame)
    end
 
    it 'renders the standard share frame subject' do
      @email.subject.should eq(Settings::Email.share_frame['subject'] % {:sharers_name => "dan"})
    end
    
    it 'renders the private roll invite subject' do
      @frame.roll.public = false
      @frame.roll.save
      @email = SharingMailer.share_frame(@from_user, @from_user.primary_email, @to_email, @message, @frame)
      @email.subject.should eq(Settings::Email.share_frame['private_roll_invite_subject'] % {:inviters_name => "dan", :roll_title => @roll_title})
    end
    
    it 'renders the receiver email' do
      @email.to.should eq([@to_email])
    end
    
    it 'renders the sender email' do
      @email.from.should eq([@from_user.primary_email])
    end
    
    #ensure that the an instance var is assigned properly, eg @confirmation_url variable appears in the email body
    #it 'assigns @confirmation_url' do
    #  mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    #end
  end
end