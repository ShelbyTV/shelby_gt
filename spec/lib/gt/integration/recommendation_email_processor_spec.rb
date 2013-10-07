# encoding: UTF-8

require 'spec_helper'

require 'recommendation_email_processor'

# INTEGRATION test
describe GT::RecommendationEmailProcessor do

  before(:each) do
    @featured_channel_user = Factory.create(:user)
    Settings::Channels['featured_channel_user_id'] = @featured_channel_user.id.to_s
    GT::VideoProviderApi.stub(:get_video_info)
  end

  describe "process_send_weekly_rec_email_for_users" do
    before(:each) do
      @new_now = 10.years.ago
      Time.stub(:now).and_return(@new_now)
      APIClients::KissMetrics.stub(:identify_and_record)
    end

    it "skips processing users who don't have an email address" do
      user = Factory.create(:user, :id => BSON::ObjectId.from_time(@new_now, {:unique => true}))
      user.preferences.email_updates = true
      user.primary_email = ""
      user.save
      GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users.should == {
        :users_scanned => 0,
        :user_sendable => 0,
        :sent_emails => 0,
        :no_user_recommendations => 0,
        :errors => 0
      }
      user.destroy

      user = Factory.create(:user, :id => BSON::ObjectId.from_time(@new_now, {:unique => true}))
      user.primary_email = nil
      user.save
      GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users.should == {
        :users_scanned => 0,
        :user_sendable => 0,
        :sent_emails => 0,
        :no_user_recommendations => 0,
        :errors => 0
      }
      user.destroy
    end

    it "skips processing users who have notification preferences set to false" do
      user = Factory.create(:user, :id => BSON::ObjectId.from_time(@new_now, {:unique => true}))
      user.preferences.email_updates = false
      user.primary_email = "user@example.com"
      user.save
      GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users.should == {
        :users_scanned => 0,
        :user_sendable => 0,
        :sent_emails => 0,
        :no_user_recommendations => 0,
        :errors => 0
      }
      user.destroy
    end

    it "skips processing users who are not real" do
      user = Factory.create(:user, :id => BSON::ObjectId.from_time(@new_now, {:unique => true}))
      user.preferences.email_updates = true
      user.primary_email = "user@example.com"
      user.user_type = User::USER_TYPE[:faux]
      user.save

      APIClients::KissMetrics.should_not_receive(:identify_and_record)

      GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users.should == {
        :users_scanned => 1,
        :user_sendable => 0,
        :sent_emails => 0,
        :no_user_recommendations => 0,
        :errors => 0
      }
      user.destroy
    end

    it "skips emailing to users who have no recommendations available" do
      user = Factory.create(:user, :id => BSON::ObjectId.from_time(@new_now, {:unique => true}))
      user.preferences.email_updates = true
      user.primary_email = "user@example.com"
      user.save

      APIClients::KissMetrics.should_not_receive(:identify_and_record)

      expect {
        @result = GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users
      }.not_to change(ActionMailer::Base.deliveries,:size)

      @result.should == {
        :users_scanned => 1,
        :user_sendable => 1,
        :sent_emails => 0,
        :no_user_recommendations => 1,
        :errors => 0
      }
      user.destroy
    end

    it "sticks to users with specified nicknames if :user_nicknames option is passed" do
      user = Factory.create(:user, :id => BSON::ObjectId.from_time(@new_now, {:unique => true}))
      user.preferences.email_updates = true
      user.primary_email = "user@example.com"
      user.nickname = "frank"
      user.save

      user2 = Factory.create(:user, :id => BSON::ObjectId.from_time(@new_now, {:unique => true}))
      user2.preferences.email_updates = true
      user2.primary_email = "user2@example.com"
      user2.nickname = "earnest"
      user2.save

      GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users({:user_nicknames => ['earnest']}).should == {
        :users_scanned => 1,
        :user_sendable => 1,
        :sent_emails => 0,
        :no_user_recommendations => 1,
        :errors => 0
      }

      user.destroy
      user2.destroy
    end

    describe "has some recommendations" do

      before(:each) do
        @user = Factory.create(:user, :id => BSON::ObjectId.from_time(@new_now, {:unique => true}))
        @user.preferences.email_updates = true
        @user.primary_email = "user@example.com"
        @user.save

        #create a channel rec
        @featured_curator = Factory.create(:user)
        @conversation = Factory.create(:conversation)
        @message = Factory.create(:message, :text => "Some interesting text", :user_id => @featured_curator.id)
        @conversation.messages << @message
        @conversation.save
        @channel_recommended_vid = Factory.create(:video)
        @community_channel_frame = Factory.create(:frame, :creator_id => @featured_curator.id, :video_id => @channel_recommended_vid.id, :conversation_id => @conversation.id)
        @community_channel_dbe = Factory.create(:dashboard_entry, :user_id => @featured_channel_user.id, :frame_id => @community_channel_frame.id, :video_id => @channel_recommended_vid.id)
      end

      it "sends emails to users who have recommendations" do
        APIClients::KissMetrics.should_receive(:identify_and_record)

        expect {
          @result = GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users
        }.to change(ActionMailer::Base.deliveries,:size).by(1)

        @result.should == {
          :users_scanned => 1,
          :user_sendable => 1,
          :sent_emails => 1,
          :no_user_recommendations => 0,
          :errors => 0
        }
        @user.destroy
      end

      it "doesn't send emails when :send_emails => false is passed" do
        APIClients::KissMetrics.should_not_receive(:identify_and_record)

        expect {
          @result = GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users({:send_emails => false})
        }.to_not change(ActionMailer::Base.deliveries,:size)

        @result.should == {
          :users_scanned => 1,
          :user_sendable => 1,
          :sent_emails => 0,
          :no_user_recommendations => 0,
          :errors => 0
        }
        @user.destroy
      end

      it "returns stats on errors" do
        GT::RecommendationEmailProcessor.stub(:process_and_send_recommendation_email_for_user).and_raise()

        APIClients::KissMetrics.should_not_receive(:identify_and_record)

        GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users.should == {
          :users_scanned => 1,
          :user_sendable => 1,
          :sent_emails => 0,
          :no_user_recommendations => 0,
          :errors => 1
        }
        @user.destroy
      end

    end

  end

  describe "process_and_send_recommendation_email_for_user" do

    before(:each) do
      @user = Factory.create(:user)
      @user.viewed_roll = Factory.create(:roll, :creator => @user)
    end

    it "does nothing if no recommendations are available" do
      expect {
        @result = GT::RecommendationEmailProcessor.process_and_send_recommendation_email_for_user(@user)
      }.not_to change(ActionMailer::Base.deliveries,:size)
      @result.should be_nil
    end

    it "sends an email if recommendations are available" do
      #create a channel rec
      @featured_curator = Factory.create(:user)
      @conversation = Factory.create(:conversation)
      @message = Factory.create(:message, :text => "Some interesting text", :user_id => @featured_curator.id)
      @conversation.messages << @message
      @conversation.save
      @channel_recommended_vid = Factory.create(:video)
      @community_channel_frame = Factory.create(:frame, :creator_id => @featured_curator.id, :video_id => @channel_recommended_vid.id, :conversation_id => @conversation.id)
      @community_channel_dbe = Factory.create(:dashboard_entry, :user_id => @featured_channel_user.id, :frame_id => @community_channel_frame.id, :video_id => @channel_recommended_vid.id)
      GT::MortarHarvester.stub(:get_recs_for_user).and_return(nil)

      expect {
        @result = GT::RecommendationEmailProcessor.process_and_send_recommendation_email_for_user(@user)
      }.to change(ActionMailer::Base.deliveries,:size).by(1)
      @result.should == 1
    end

  end

end
