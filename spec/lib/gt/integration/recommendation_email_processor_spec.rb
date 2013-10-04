# encoding: UTF-8

require 'spec_helper'

require 'recommendation_email_processor'

# INTEGRATION test
describe GT::RecommendationEmailProcessor do

  before(:each) do
    @user = Factory.create(:user)
    @user.viewed_roll = Factory.create(:roll, :creator => @user)
    @featured_channel_user = Factory.create(:user)
    Settings::Channels['featured_channel_user_id'] = @featured_channel_user.id.to_s
    GT::VideoProviderApi.stub(:get_video_info)
  end

  context "new implementation" do

    context "process_and_send_recommendation_email_for_user" do

      it "does nothing if no recommendations are available" do
        GT::RecommendationEmailProcessor.process_and_send_recommendation_email_for_user(@user).should be_nil
        expect {
          GT::RecommendationEmailProcessor.process_and_send_recommendation_email_for_user(@user)
        }.not_to change(ActionMailer::Base.deliveries,:size)
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

        GT::RecommendationEmailProcessor.process_and_send_recommendation_email_for_user(@user).should_not be_nil
      end

    end

  end

end
