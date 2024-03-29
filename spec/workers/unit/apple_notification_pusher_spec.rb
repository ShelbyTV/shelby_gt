require 'spec_helper'

describe AppleNotificationPusher do

  before(:each) do
    @houston_connection = double("houston_connection", :open => nil, :write => nil)
    Houston::Connection.stub(:new).and_return(@houston_connection)

    @houston_notification_message = double("houston_notification_message")

    @houston_notification = double("houston_notification", :message => @houston_notification_message)
    Houston::Notification.stub(:new).and_return(@houston_notification)

    @options = {:device => "some token", :alert => "Here's a notification from Shelby.tv"}

    AppleNotificationPusher.instance_variable_set(:@apn_connection, nil)

    ResqueSpec.reset!
  end

  it "opens a connection" do
    Houston::Connection.should_receive(:new).and_return(@houston_connection)
    @houston_connection.should_receive(:open)

    Resque.enqueue(AppleNotificationPusher, @options)

    AppleNotificationPusher.should have_queue_size_of(1)

    ResqueSpec.perform_next(:apple_push_notifications_queue)
  end

  it "doesn't open a connection if it already has one" do
    Houston::Connection.should_receive(:new).once().and_return(@houston_connection)
    Resque.enqueue(AppleNotificationPusher, @options)
    Resque.enqueue(AppleNotificationPusher, @options)
    ResqueSpec.perform_all(:apple_push_notifications_queue)
  end

  it "pushes a notification" do
    Houston::Notification.should_receive(:new).with(@options).and_return(@houston_notification)
    @houston_connection.should_receive(:write).with(@houston_notification_message)
    APIClients::GoogleAnalyticsClient.should_not_receive(:track_event)

    Resque.enqueue(AppleNotificationPusher, @options)
    ResqueSpec.perform_next(:apple_push_notifications_queue)
  end

  it "tracks an event with Google Analytics if requested" do
    @options[:ga_event] = {:category => "Category", :action => "Action", :label => "Label"}

    APIClients::GoogleAnalyticsClient.should_receive(:track_event).with(
      "Category",
      "Action",
      "Label",
      {
        :account_id => Settings::GoogleAnalytics.web_account_id,
        :domain => Settings::Global.domain
      }
    )

    Resque.enqueue(AppleNotificationPusher, @options)
    ResqueSpec.perform_next(:apple_push_notifications_queue)
  end
end