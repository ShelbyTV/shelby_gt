require 'spec_helper'

describe SharingMailer do
  describe 'share frame' do
    before(:each) do
      @from_user = Factory.create(:user, :name => "dan")
      @to_email = Factory.next :primary_email
      @message = "wassssuuuup!"
      @video = Factory.create(:video, :thumbnail_url => "http://url.com/123.jpg", :title=>"blah")
      @roll = Factory.create(:roll, :creator => @from_user)
      @roll_title = @roll.title
    end

    context 'frame is a real frame' do

      before(:each) do
        @frame = Factory.create(:frame, :creator_id => @from_user.id, :video_id => @video.id, :roll => @roll)
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

      it 'renders the video title' do
        @email.body.to_s.should have_tag 'td', :text => @frame.video.title
      end

      it 'renders the permalink' do
        @email.body.to_s.should have_tag 'a', :with => {:href => @frame.permalink}
      end

      it 'renders the thumbnail' do
        @email.body.to_s.should have_tag 'img', :with => {:src => @frame.video.thumbnail_url}
      end

    end

    context 'frame is actually a video' do

      before(:each) do
        @frame = @video
        @email = SharingMailer.share_frame(@from_user, @from_user.primary_email, @to_email, @message, @frame)
      end

      it 'renders the video title' do
        @email.body.to_s.should have_tag 'td', :text => @video.title
      end

      it 'renders the permalink' do
        @email.body.to_s.should have_tag 'a', :with => {:href => @video.permalink}
      end

      it 'renders the thumbnail' do
        @email.body.to_s.should have_tag 'img', :with => {:src => @video.thumbnail_url}
      end

    end

  end
end