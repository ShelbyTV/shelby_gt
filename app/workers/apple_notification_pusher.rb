require 'houston'

class AppleNotificationPusher
  @queue = :apple_push_notifications_queue

  def self.perform(options)
    # when resque serializes the options, it changes the keys from symbols to strings
    # so, we change them back to symbols because that's what our code is expecting
    options = options.symbolize_keys

    notification = Houston::Notification.new(options)
    @apn_connection.write(notification.message)
  end

  # before performing a job, check if we have a connection to APNs in a good state, otherwise create one
  def self.before_perform_check_connection(*args)
    unless @apn_connection
      @apn_connection = Houston::Connection.new(
        ENV['RAILS_ENV'] == 'production' ? Houston::APPLE_PRODUCTION_GATEWAY_URI : Houston::APPLE_DEVELOPMENT_GATEWAY_URI,
        File.read(File.join(Dir.pwd, "certificates/iOS/NightlyDev.pem")),
        nil
      )
      @apn_connection.open
    end
  end

end