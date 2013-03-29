require 'spec_helper'

describe EmailWebhookController do

  before(:all) do
    @rolling_address = "#{Settings::EmailHook.email_user_keys['roll']}@#{Settings::EmailHook.email_hook_domain}"
    @channel_tag = "test"
    @channel_rolling_address = "test@#{Settings::EmailHook.email_hook_domain}"
    @hashtag_roll_user = Factory.create(:user)
    Settings::Channels.channels[0]['channel_user_id'] = @hashtag_roll_user.id.to_s
    Settings::Channels.channels[0]['hash_tags'] = [@channel_tag]

  end

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

    context "can match from: email to shelby user" do

      before(:each) do
        User.stub(:find_by_primary_email).and_return(@u)
      end

      it "returns http success" do
        post :hook
        response.should be_success
      end

      it "finds the user" do
        User.should_receive(:find_by_primary_email).with(@u.primary_email)

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

      it "finds links and tries to make video objects out of them" do
        GT::VideoManager.should_receive(:get_or_create_videos_for_url).with("www.youtube.com")
        GT::VideoManager.should_receive(:get_or_create_videos_for_url).with("http://example.com?name=val")

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

      it "finds links that don't start with http or www" do
        GT::VideoManager.should_receive(:get_or_create_videos_for_url).with("vimeo.com/12345")

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@rolling_address}\n", :text => "vimeo.com/12345"
      end

      it "creates a default message if the email has no subject" do
        GT::MessageManager.should_receive(:build_message).with({
          :user => @u,
          :public => true,
          :text => Settings::EmailHook.default_rolling_comment
        })

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

      it "uses the email subject as the rolling message if there is one" do
        GT::MessageManager.should_receive(:build_message).with({
          :user => @u,
          :public => true,
          :text => "The email subject"
        })

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val", :subject => "The email subject"
      end

      it "appends a hashtag to the message if the user emailed to matches a channel hashtag" do
        GT::MessageManager.should_receive(:build_message).with({
          :user => @u,
          :public => true,
          :text => "The email subject \##{@channel_tag}"
        })

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@channel_rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val", :subject => "The email subject"
      end

      it "doesn't append a hashtag if the message already has it" do
        GT::MessageManager.should_receive(:build_message).with({
          :user => @u,
          :public => true,
          :text => "The \##{@channel_tag} email subject"
        })

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@channel_rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val", :subject => "The \##{@channel_tag} email subject"
      end

      it "creates frames from the videos" do
        GT::Framer.should_receive(:create_frame).with({
          :action => DashboardEntry::ENTRY_TYPE[:new_email_hook_frame],
          :creator => @u,
          :message => @m,
          :roll => @r,
          :video => @v
        })

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

      it "creates a rolling user action" do
        # A Frame was rolled, track that user action
        GT::UserActionManager.should_receive(:frame_rolled!).with(@u.id, @f.id, @v.id, @r.id)

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:#{@rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

      it "does nothing if the email is not sent to the 'roll' address or a channel hashtag" do
        GT::VideoManager.should_not_receive(:get_or_create_videos_for_url)

        post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\nTo:bob@volumevolume.com\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

    end

    context "can't match from: email to shelby user" do

      it "shouldn't do anything if it can't match the email to a shelby user" do
        GT::VideoManager.should_not_receive(:get_or_create_videos_for_url)

        post :hook, :headers => "From: Some Unknown Guy <unknown@unknown.com>\nTo:#{@rolling_address}\n", :text => "www.youtube.com here's an email http://example.com?name=val"
      end

    end
  end

end