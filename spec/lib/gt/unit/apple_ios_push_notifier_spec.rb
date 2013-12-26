require 'spec_helper'
require 'apple_ios_push_notifier'

describe GT::AppleIOSPushNotifier do

  before(:each) do
    ResqueSpec.reset!
  end

  context "push_notification_to_user_devices_async" do

    before(:each) do
      @user = Factory.create(:user, :apn_tokens => ['token1'])
    end

    it "queues a Resque job to send a push notification to a user" do
      GT::AppleIOSPushNotifier.push_notification_to_user_devices_async(@user, "Here is your message")

      expect(AppleNotificationPusher).to have_queue_size_of(1)
      expect(AppleNotificationPusher).to have_queued({:device => 'token1', :alert => "Here is your message"})
    end

    it "adds a custom data to the notification if specified" do
      GT::AppleIOSPushNotifier.push_notification_to_user_devices_async(@user, "Here is your message", {:dashboard_entry_id => '123'})

      expect(AppleNotificationPusher).to have_queue_size_of(1)
      expect(AppleNotificationPusher).to have_queued({
        :device => 'token1',
        :alert => "Here is your message",
        :dashboard_entry_id => '123'
      })
    end

    it "queues multiple jobs if the user has multiple devices registered" do
      @user.apn_tokens = ['token1', 'token2']

      GT::AppleIOSPushNotifier.push_notification_to_user_devices_async(@user, "Here is your message")

      expect(AppleNotificationPusher).to have_queue_size_of(2)
    end

    it "doesn't queue anything if the user has no device tokens" do
      @user.apn_tokens = []

      GT::AppleIOSPushNotifier.push_notification_to_user_devices_async(@user, "Here is your message")

      expect(AppleNotificationPusher).to have_queue_size_of(0)
    end

  end

  context "push_notification_to_devices_async" do
    it "queues a Resque job to send a push notification to each specified device" do
      GT::AppleIOSPushNotifier.push_notification_to_devices_async(['token1'], "Here is your message")

      expect(AppleNotificationPusher).to have_queue_size_of(1)
      expect(AppleNotificationPusher).to have_queued({:device => 'token1', :alert => "Here is your message"})
    end
  end

end