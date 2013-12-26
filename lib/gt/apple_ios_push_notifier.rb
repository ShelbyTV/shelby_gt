module GT
  class AppleIOSPushNotifier

    # given a user, push a notification to all of their iOS devices, asynchronously
    def self.push_notification_to_user_devices_async(user, alert, custom_data=nil)
      push_notification_to_devices_async(user.apn_tokens, alert, custom_data)
    end

    # given a list of ios device tokens, push a notification to all of them, asynchronously
    def self.push_notification_to_devices_async(devices, alert, custom_data=nil)
      devices.each do |token|
        options = { :device => token, :alert => alert}
        options = options.merge(custom_data) if custom_data
        Resque.enqueue(AppleNotificationPusher, options)
      end
    end

  end
end