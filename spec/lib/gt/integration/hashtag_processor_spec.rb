require 'spec_helper'
require 'hashtag_processor'

# INTEGRATION test
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

    it "should create the new db entry in the database" do
      @message.text = "I am #testing this feature"
      @conversation.messages << @message

      lambda {
        res = GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
      }.should change { DashboardEntry.count } .by(1)
    end

    it "should create and return the proper dashboard entry" do
      @message.text = "I am #testing this feature"
      @conversation.messages << @message

      res = GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
      res.frame.should == @frame
      res.user.should == @hashtag_channel_user
      res.action.should == ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame]
    end

  end

end
