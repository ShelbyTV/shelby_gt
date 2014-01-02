module GT
  class AppleIOSPushNotifier

    # given a user, push a notification to all of their iOS devices, asynchronously
    def self.push_notification_to_user_devices_async(user, alert, options={})
      push_notification_to_devices_async(user.apn_tokens, alert, options)
    end

    # given a list of ios device tokens, push a notification to all of them, asynchronously
    def self.push_notification_to_devices_async(devices, alert, options={})
      defaults = {
        :sound => "default",
      }

      options = defaults.merge(options)

      devices.each do |token|
        notification_options = { :device => token, :alert => alert}.merge(options)
        Resque.enqueue(AppleNotificationPusher, notification_options)
      end
    end

  end
end