require 'spec_helper'
require 'hashtag_processor'
require 'api_clients/google_analytics_client'

# UNIT test
describe GT::HashtagProcessor do
  before(:each) do
    @rolling_user = Factory.create(:user)
    @hashtag_channel_user1 = Factory.create(:user)
    @hashtag_channel_user2 = Factory.create(:user)
    @conversation = Factory.create(:conversation)
    @message = Factory.create(:message, :user => @rolling_user)
    @frame = Factory.create(:frame, :conversation => @conversation)
    Settings::Channels.channels[0]['channel_user_id'] = @hashtag_channel_user1.id.to_s
    Settings::Channels.channels[0]['hash_tags'] = ['test', 'testing']
    Settings::Channels.channels[1]['channel_user_id'] = @hashtag_channel_user2.id.to_s
    Settings::Channels.channels[1]['hash_tags'] = ['test2']

    APIClients::GoogleAnalyticsClient.stub(:track_event)
  end

  context "process_frame_message_hashtags_for_channels" do

    it "should validate the arguments" do
      lambda {
        GT::HashtagProcessor.process_frame_message_hashtags_for_channels(nil)
      }.should raise_error ArgumentError

      lambda {
        GT::HashtagProcessor.process_frame_message_hashtags_for_channels('notaframe')
      }.should raise_error ArgumentError
    end

    it "should add the frame to a user's dashboard if it finds a hashtag" do
      @message.text = "I am #testing this feature"
      @conversation.messages << @message

      User.should_receive(:find).with(@hashtag_channel_user1.id.to_s).and_return(@hashtag_channel_user1)
      GT::Framer.should_receive(:create_dashboard_entry).with(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], @hashtag_channel_user1).and_return([Factory.create(:dashboard_entry)])

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "should work for any hashtag specified for the channel" do
      @message.text = "I am #test ing this feature"
      @conversation.messages << @message

      User.should_receive(:find).with(@hashtag_channel_user1.id.to_s).and_return(@hashtag_channel_user1)
      GT::Framer.should_receive(:create_dashboard_entry).with(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], @hashtag_channel_user1).and_return([Factory.create(:dashboard_entry)])

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "hashtag processing should be case insensitive" do
      @message.text = "#TEST"
      @conversation.messages << @message

      User.should_receive(:find).with(@hashtag_channel_user1.id.to_s).and_return(@hashtag_channel_user1)
      GT::Framer.should_receive(:create_dashboard_entry).with(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], @hashtag_channel_user1).and_return([Factory.create(:dashboard_entry)])

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "should process multiple hastags in a message" do
      @message.text = "#testing #test2 #ignorethisone one two"
      @conversation.messages << @message

      GT::Framer.should_receive(:create_dashboard_entry).with(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], @hashtag_channel_user1).and_return([Factory.create(:dashboard_entry)])
      GT::Framer.should_receive(:create_dashboard_entry).with(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], @hashtag_channel_user2).and_return([Factory.create(:dashboard_entry)])

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "should post a google analytics event for every hashtag seen, even those that don't match channels" do
      @message.text = "#tEsting #test2 #ignoreTHISone one two"
      @conversation.messages << @message

      APIClients::GoogleAnalyticsClient.should_receive(:track_event).with('hashtag', 'rolled to', 'testing')
      APIClients::GoogleAnalyticsClient.should_receive(:track_event).with('hashtag', 'rolled to', 'test2')
      APIClients::GoogleAnalyticsClient.should_receive(:track_event).with('hashtag', 'rolled to', 'ignorethisone')

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "should not post google analytics events if the opt out parameter (second parameters) is passed as false" do
      @message.text = "#tEsting #test2 #ignoreTHISone one two"
      @conversation.messages << @message

      APIClients::GoogleAnalyticsClient.should_not_receive(:track_event)

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame, false)
    end

    it "should add only once to a given channel" do
      @message.text = "#testing #test one two"
      @conversation.messages << @message

      GT::Framer.should_receive(:create_dashboard_entry).exactly(1).times.and_return([Factory.create(:dashboard_entry)])

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "should not add the frame to anything if the hashtags don't match any channels" do
      @message.text = "Ignore #theseotherhashtags here"
      @conversation.messages << @message

      Settings::Channels.channels.should_receive(:each)
      GT::Framer.should_not_receive(:create_dashboard_entry)

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "should not do anything if the message has no hashtags" do
      @message.text = "No hashtags"
      @conversation.messages << @message

      Settings::Channels.channels.should_not_receive(:each)

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

  end
end