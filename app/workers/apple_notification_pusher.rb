require 'houston'

class AppleNotificationPusher
  @queue = :apple_push_notifications_queue

  def self.perform(options)
    # when resque serializes the options, it changes the keys from symbols to strings
    # so, we change them back to symbols because that's what our code is expecting
    options = options.symbolize_keys

    ga_event = options.delete(:ga_event)

    notification = Houston::Notification.new(options)
    @apn_connection.write(notification.message)

    if ga_event
      APIClients::GoogleAnalyticsClient.track_event(
        ga_event["category"],
        ga_event["action"],
        ga_event["label"],
        {
          :account_id => Settings::GoogleAnalytics.web_account_id,
          :domain => Settings::Global.domain
        }
      )
    end
  end

  # before performing a job, check if we have a connection to APNs in a good state, otherwise create one
  def self.before_perform_check_connection(*args)
    unless @apn_connection
      certificate_path = (ENV['RAILS_ENV'] == 'production' ? "certificates/iOS/LiveProd.pem" : "certificates/iOS/NightlyProd.pem")
      @apn_connection = Houston::Connection.new(
        Houston::APPLE_PRODUCTION_GATEWAY_URI,
        File.read(File.join(Dir.pwd, certificate_path)),
        nil
      )
      @apn_connection.open
    end
  end

end