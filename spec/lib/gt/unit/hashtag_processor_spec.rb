require 'spec_helper'
require 'hashtag_processor'

# UNIT test
describe GT::HashtagProcessor do
  before(:each) do
    @rolling_user = Factory.create(:user)
    @hashtag_channel_user = Factory.create(:user)
    @conversation = Factory.create(:conversation)
    @message = Factory.create(:message, :user => @rolling_user)
    @frame = Factory.create(:frame, :conversation => @conversation)
    Settings::Channels.channels[0]['channel_user_id'] = @hashtag_channel_user.id.to_s
    Settings::Channels.channels[0]['hash_tags'] = ['test', 'testing']
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

      User.should_receive(:find).with(@hashtag_channel_user.id.to_s).and_return(@hashtag_channel_user)
      GT::Framer.should_receive(:create_dashboard_entry).with(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], @hashtag_channel_user)

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "should work for any hashtag specified for the channel" do
      @message.text = "I am #test ing this feature"
      @conversation.messages << @message

      User.should_receive(:find).with(@hashtag_channel_user.id.to_s).and_return(@hashtag_channel_user)
      GT::Framer.should_receive(:create_dashboard_entry).with(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], @hashtag_channel_user)

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "hashtag processing should be case insensitive" do
      @message.text = "#TEST"
      @conversation.messages << @message

      User.should_receive(:find).with(@hashtag_channel_user.id.to_s).and_return(@hashtag_channel_user)
      GT::Framer.should_receive(:create_dashboard_entry).with(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], @hashtag_channel_user)

      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
    end

    it "should only process one hashtag per message" do
      @message.text = "#testing #test one two"
      @conversation.messages << @message

      GT::Framer.should_receive(:create_dashboard_entry).exactly(1).times

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