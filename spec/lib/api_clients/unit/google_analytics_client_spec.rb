# encoding: UTF-8

require 'spec_helper'
require 'api_clients/google_analytics_client'

# UNIT test
describe APIClients::GoogleAnalyticsClient do

    before(:each) do
      @web_property_client = double("web_property_client")
      @ios_property_client = double("ios_property_client")
    end

    it "initializes a Gabba client once for each property" do
      Gabba::Gabba.should_receive(:new).once().with(Settings::GoogleAnalytics.web_account_id, Settings::Global.domain).ordered()
      Gabba::Gabba.should_receive(:new).once().with(Settings::GoogleAnalytics.ios_account_id, Settings::Global.domain).ordered()

      APIClients::GoogleAnalyticsClient.track_event("Category", "Action", "Label")
      APIClients::GoogleAnalyticsClient.track_event("Category", "Action", "Label2")

      APIClients::GoogleAnalyticsClient.track_event("Category2", "Action2", "Label", {:account_id => Settings::GoogleAnalytics.ios_account_id, :domain => Settings::Global.domain})
      APIClients::GoogleAnalyticsClient.track_event("Category2", "Action2", "Label2", {:account_id => Settings::GoogleAnalytics.ios_account_id, :domain => Settings::Global.domain})
    end

    it "passes through required parameters to Gabba event tracking" do
      @ga_client.should_receive(:event).with("Category", "Action", "Label", nil)

      APIClients::GoogleAnalyticsClient.track_event("Category", "Action", "Label")
    end

    it "passes through optional event value to Gabba event tracking" do
      @ga_client.should_receive(:event).with("Category", "Action", "Label", 1)

      APIClients::GoogleAnalyticsClient.track_event("Category", "Action", "Label", {:value => 1})
    end

end