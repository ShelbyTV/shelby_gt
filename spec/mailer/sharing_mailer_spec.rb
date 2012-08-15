require 'spec_helper'
 
describe SharingMailer do
  describe 'share frame' do
    before(:each) do
      @from_user = Factory.create(:user, :name => "dan")
      @to_email = Factory.next :primary_email
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
    
    it 'renders the receiver email' do
      @email.to.should eq([@to_email])
    end
    
    it 'renders the sender email' do
      @email.from.should eq([@from_user.primary_email])
    end

  end
end