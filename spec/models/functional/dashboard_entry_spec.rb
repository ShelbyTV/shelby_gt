require 'spec_helper'

#Functional: hit the database, treat model as black box
describe DashboardEntry do
  before(:each) do
    @dashboard_entry = DashboardEntry.new
  end

  context "database" do

    it "should have an index on [user_id, id]" do
      indexes = DashboardEntry.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1, "_id"=>-1})
    end

    it "should abbreviate user_id as :a" do
      DashboardEntry.keys["user_id"].abbr.should == :a
    end

  end

  context "permalinks" do

    before(:each) do
      @channel_user = Factory.create(:user)
      Settings::Channels.channels[0]['channel_user_id'] = @channel_user.id.to_s
      Settings::Channels.channels[0]['channel_route'] = 'channel1'
    end

    it "should generate permalinks for dashboard entry on a channel" do
      @dashboard_entry.user = @channel_user
      @dashboard_entry.permalink.should == "#{Settings::ShelbyAPI.web_root}/channels/#{Settings::Channels.channels[0]['channel_route']}/#{@dashboard_entry.id}"
    end

    it "should generate permalinks for a dashboard entry on a standard user dashboard by returning the permalink to the entry's frame" do
      non_channel_user = Factory.create(:user)
      frame = Factory.create(:frame)
      @dashboard_entry.user = non_channel_user
      @dashboard_entry.frame = frame

      @dashboard_entry.permalink.should == "#{Settings::ShelbyAPI.web_root}/rollFromFrame/#{@dashboard_entry.frame.id}"
    end

  end

end
