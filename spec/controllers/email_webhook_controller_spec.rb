require 'spec_helper'

describe EmailWebhookController do

  before(:each) do
    @r = Factory.create(:roll)
    @u = Factory.create(:user, :public_roll => @r)
    @v = Factory.create(:video)
    @f = Factory.create(:frame, :roll => @r, :video => @v)
    @m = Factory.create(:message, :user => @u)
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return({:videos => [@v]})
    GT::MessageManager.stub(:build_message).and_return(@m)
    GT::Framer.stub(:create_frame).and_return({:frame => @f})
    GT::UserActionManager.stub(:frame_rolled!)
  end

  describe "POST 'hook'" do

    context "can match email to shelby user" do

      before(:each) do
        User.stub(:find_by_primary_email).and_return(@u)
      end

      it "returns http success" do
        post :hook
        response.should be_success
      end

      it "finds the user" do
        User.should_receive(:find_by_primary_email).with(@u.primary_email)

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\n"
      end

      it "finds links and tries to make video objects out of them" do
        GT::VideoManager.should_receive(:get_or_create_videos_for_url).with("www.youtube.com")
        GT::VideoManager.should_receive(:get_or_create_videos_for_url).with("http://example.com?name=val")

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

      it "creates frames from the videos" do
        GT::Framer.should_receive(:create_frame).with({
          :action => DashboardEntry::ENTRY_TYPE[:new_email_hook_frame],
          :creator => @u,
          :message => @m,
          :roll => @r,
          :video => @v
        })

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

      it "creates a rolling user action" do
        # A Frame was rolled, track that user action
        GT::UserActionManager.should_receive(:frame_rolled!).with(@u.id, @f.id, @v.id, @r.id)

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

    end

    context "can't match email to shelby user" do

      it "shouldn't do anything if it can't match the email to a shelby user" do
        GT::VideoManager.should_not_receive(:get_or_create_videos_for_url)

        post :hook, :headers => "From: Some Unknown Guy <unknown@unknown.com>\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

    end
  end

end