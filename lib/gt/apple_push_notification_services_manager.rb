module GT
  class ApplePushNotificationServicesManager

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

    # connect to the APNS feedback service and get a list of invalidated device tokens
    def self.get_invalid_devices_from_feedback_service
      client = Houston::Client.send(Settings::PushNotifications.houston_client_environment_method)
      client.certificate = File.read(File.join(Dir.pwd, Settings::PushNotifications.certificate_file))
      client.devices.map { |token| "<#{token}>" }
    end

    def self.remove_device_tokens(tokens=[])
      unless tokens.empty?
        result = User.collection.update(
          {
            :$and => [
              {:_id => {:$lte => BSON::ObjectId.from_time(Time.at(Time.now.utc.to_f.ceil))}},
              {:bh => {:$in => tokens}}
            ]
          },
          {
            :$pullAll => {:bh => tokens}
          },
          {
            :multi => true,
            :w => 1
          }
        )
        Rails.logger.info "DB update #{result == true ? 'succeeded' : 'failed'}"
        Rails.logger.info result.inspect unless result == true
      end
    end

  end
end