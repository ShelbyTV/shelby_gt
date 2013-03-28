require 'spec_helper'

describe EmailWebhookController do

  before(:each) do
    @r = Factory.create(:roll)
    @u = Factory.create(:user, :public_roll => @r)
    @v = Factory.create(:video)
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return({:videos => [@v]})
  end

  describe "POST 'hook'" do

      it "creates a frame from the link" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\n")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
        }.should change { Frame.count } .by(1)

      end

      it "creates the frame on the user's personal roll" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\n")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
        }.should change { @r.frame_count } .by(1)

      end

  end

end