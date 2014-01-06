require 'spec_helper'
require 'apple_push_notification_services_manager'

describe GT::ApplePushNotificationServicesManager do

  before(:each) do
    ResqueSpec.reset!
  end

  context "push_notification_to_user_devices_async" do

    before(:each) do
      @user = Factory.create(:user, :apn_tokens => ['token1'])
    end

    it "queues a Resque job to send a push notification to a user" do
      GT::ApplePushNotificationServicesManager.push_notification_to_user_devices_async(@user, "Here is your message")

      expect(AppleNotificationPusher).to have_queue_size_of(1)
      expect(AppleNotificationPusher).to have_queued({:device => 'token1', :alert => "Here is your message", :sound => 'default'})
    end

    it "adds a custom data to the notification if specified" do
      GT::ApplePushNotificationServicesManager.push_notification_to_user_devices_async(@user, "Here is your message", {:dashboard_entry_id => '123'})

      expect(AppleNotificationPusher).to have_queue_size_of(1)
      expect(AppleNotificationPusher).to have_queued({
        :device => 'token1',
        :alert => "Here is your message",
        :sound => 'default',
        :dashboard_entry_id => '123'
      })
    end

    it "queues multiple jobs if the user has multiple devices registered" do
      @user.apn_tokens = ['token1', 'token2']

      GT::ApplePushNotificationServicesManager.push_notification_to_user_devices_async(@user, "Here is your message")

      expect(AppleNotificationPusher).to have_queue_size_of(2)
    end

    it "doesn't queue anything if the user has no device tokens" do
      @user.apn_tokens = []

      GT::ApplePushNotificationServicesManager.push_notification_to_user_devices_async(@user, "Here is your message")

      expect(AppleNotificationPusher).to have_queue_size_of(0)
    end

  end

  context "push_notification_to_devices_async" do
    it "queues a Resque job to send a push notification to each specified device" do
      GT::ApplePushNotificationServicesManager.push_notification_to_devices_async(['token1'], "Here is your message")

      expect(AppleNotificationPusher).to have_queue_size_of(1)
      expect(AppleNotificationPusher).to have_queued({:device => 'token1', :alert => "Here is your message", :sound => 'default'})
    end
  end

  context "get_invalid_devices_from_feedback_service" do
    before(:each) do
      @houston_client = double("houston_client", :certificate= => nil, :devices => [])
      Houston::Client.stub(Settings::PushNotifications.houston_client_environment_method).and_return(@houston_client)
    end

    it "creates a client connection to the feedback service" do
      Houston::Client.should_receive(Settings::PushNotifications.houston_client_environment_method)

      GT::ApplePushNotificationServicesManager.get_invalid_devices_from_feedback_service
    end

    it "calls the feedback service to get the invalid device tokens" do
      @houston_client.should_receive(:devices)

      GT::ApplePushNotificationServicesManager.get_invalid_devices_from_feedback_service
    end

    it "wraps the tokens in brackets" do
      @houston_client.stub(:devices).and_return(["token1", "token2"])

      expect(GT::ApplePushNotificationServicesManager.get_invalid_devices_from_feedback_service).to eql ["<token1>", "<token2>"]
    end
  end

  context "remove_device_tokens" do
    before(:each) do
      @user_collection = double("user_collection", :update => true)
      User.stub(:collection).and_return(@user_collection)
    end

    it "acceses DB to remove device tokens if any are passed in" do
      User.should_receive(:collection)
      @user_collection.should_receive(:update)
      GT::ApplePushNotificationServicesManager.remove_device_tokens(['<token1>', '<token3>'])
    end

    it "does nothing if no tokens are passed in" do
      User.should_not_receive(:collection)
      GT::ApplePushNotificationServicesManager.remove_device_tokens([])
    end

    it "logs appropriate message when update succeeds" do
      Rails.logger.should_receive(:info).once().with("DB update succeeded")
      GT::ApplePushNotificationServicesManager.remove_device_tokens(['<token1>', '<token3>'])
    end

    it "logs appropriate message when update fails" do
      @user_collection.stub(:update).and_return({})
      Rails.logger.should_receive(:info).ordered.with("DB update failed")
      Rails.logger.should_receive(:info).ordered.with("{}")
      GT::ApplePushNotificationServicesManager.remove_device_tokens(['<token1>', '<token3>'])
    end
  end

end