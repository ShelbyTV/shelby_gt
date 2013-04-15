require 'spec_helper'

describe EmailWebhookController do

  before(:all) do
    @rolling_address = "#{Settings::EmailHook.email_user_keys['roll']}@#{Settings::EmailHook.email_hook_domain}"
    @hashtag_roll_user = Factory.create(:user)
    Settings::Channels.channels[0]['channel_user_id'] = @hashtag_roll_user.id.to_s
    Settings::Channels.channels[0]['hash_tags'] = ['test', 'testing']
    Settings::EmailHook['max_rolled_videos'] = 2
  end

  before(:each) do
    @r = Factory.create(:roll)
    @u = Factory.create(:user, :public_roll => @r)
    @v = Factory.create(:video)
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return({:videos => [@v]})
  end

  describe "POST 'hook'" do

      it "creates a frame from the link" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
        }.should change { Frame.count } .by(1)

      end

      it "only processes the specified maximum number of links" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("three links www.link1.com www.link2.com www.link3.com")
        }.should change { Frame.count } .by(Settings::EmailHook.max_rolled_videos)

      end

      it "creates the frame on the user's personal roll" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
        }.should change { @r.frame_count } .by(1)

      end

      it "increments the user's email rolling count" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
        }.should change { @u.rolled_since_last_notification["email"] } .by(1)

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("two links http://espn.com/something http://example.com?name=val")
        }.should change { @u.rolled_since_last_notification["email"] } .by(2)

      end

      it "creates a frame if the to: address is a channel hashtag" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: test@#{Settings::EmailHook.email_hook_domain}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
        }.should change { Frame.count } .by(1)

      end

      context "hashtag processing" do


          it "creates a dashboard entry on the channel if the rolling comment contains a channel hashtag" do

            lambda {
              post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")+"&subject="+CGI::escape("here's an subject with a hashtag #test")
            }.should change { DashboardEntry.count } .by(1)

          end

          it "creates a dashboard entry on the channel if to:email contains a channel address" do

            lambda {
              post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: test@#{Settings::EmailHook.email_hook_domain}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
            }.should change { DashboardEntry.count } .by(1)

          end

          it "creates no dashboard entries if there are no channel hashtags" do

            lambda {
              post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")+"&subject="+CGI::escape("no hashtag here")
            }.should_not change { DashboardEntry.count }

          end

      end

      context "also add to community channel" do

        before(:each) do
          @community_channel_user = Factory.create(:user)
          Settings::Channels['community_channel_user_id'] = @community_channel_user.id.to_s
          @r.roll_type = Roll::TYPES[:special_public_real_user]
        end

        it "should add the frame to the community channel, also" do
          lambda {
            post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
          }.should change { DashboardEntry.count } .by(1)
        end

        it "should not add the frame to the community channel if the user is a service user" do
          @u.user_type = User::USER_TYPE[:service]
          lambda {
            post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
          }.should_not change { DashboardEntry.count }
        end

        it "should not add the frame to the community channel if the destination roll is not a real user public roll" do
          @r.roll_type = Roll::TYPES[:special_public_upgraded]
          lambda {
            post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
          }.should_not change { DashboardEntry.count }
        end

      end

      it "creates no frames if there are no links" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: #{@rolling_address}")+"&text="+CGI::escape("no links in here")
        }.should_not change { Frame.count }

      end

      it "creates no frames if it's not sent to a valid domain" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: bob@#{Settings::EmailHook.email_hook_domain}")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
        }.should_not change { Frame.count }

      end

      it "creates no frames if it's not sent to a valid email user" do

        lambda {
          post "email_webhook/hook/?headers="+CGI::escape("From: Some Guy <#{@u.primary_email}>\nTo: no.one@volumevolume.com")+"&text="+CGI::escape("here's an email with a link http://example.com?name=val")
        }.should_not change { Frame.count }

      end

  end

end