require 'spec_helper'
require 'hashtag_processor'

# INTEGRATION test
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
  end

  context "process_frame_message_hashtags_for_channels" do

    it "should create the new db entry in the database" do
      @message.text = "I am #testing this feature"
      @conversation.messages << @message

      lambda {
        res = GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
      }.should change { DashboardEntry.count } .by(1)
    end

    it "should create multiple entries for multiple hashtags" do
      @message.text = "#testing #test2 one two"
      @conversation.messages << @message

      lambda {
        res = GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
      }.should change { DashboardEntry.count } .by(2)
    end

    it "should create only one entry for each channel" do
      @message.text = "#testing #test this same channel"
      @conversation.messages << @message

      lambda {
        res = GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
      }.should change { DashboardEntry.count } .by(1)
    end

    it "should create and return the proper dashboard entry" do
      @message.text = "I am #testing this feature"
      @conversation.messages << @message

      res = GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
      res.length.should == 1
      res[0].frame.should == @frame
      res[0].user.should == @hashtag_channel_user1
      res[0].action.should == ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame]
    end

    it "should return nil if no hastags match" do
      @message.text = "no #matching hashtags"
      @conversation.messages << @message

      res = GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame)
      res.should be_nil
    end

  end

  context "process_frame_message_hashtags_send_to_google_analytics" do
    before(:all) do
      @ga_client = Gabba::Gabba.new(Settings::GoogleAnalytics.account_id, Settings::Global.domain)
    end

    before(:each) do
      @ga_client.stub(:event)
      Gabba::Gabba.stub(:new).and_return @ga_client
    end

    it "should post a google analytics event for every hashtag seen, even those that don't match channels" do
      @message.text = "#tEsting #test2 #notaCHANNEL one two"
      @conversation.messages << @message

      @ga_client.should_receive(:event).with('hashtag', 'rolled to', 'testing', nil)
      @ga_client.should_receive(:event).with('hashtag', 'rolled to', 'test2', nil)
      @ga_client.should_receive(:event).with('hashtag', 'rolled to', 'notachannel', nil)

      GT::HashtagProcessor.process_frame_message_hashtags_send_to_google_analytics(@frame)
    end

  end

end
