namespace :apns_feedback do

  desc 'Query Apple for invalidated device tokens and remove them from db'
  task :remove_invalidated_device_tokens => :environment do
    require "apple_push_notification_services_manager"

    Rails.logger = Logger.new(STDOUT)
    STDOUT.sync = true

    Rails.logger.info "Querying APNS feedback service"
    tokens = GT::ApplePushNotificationServicesManager.get_invalid_devices_from_feedback_service
    Rails.logger.info "Received #{tokens.length} invalidated tokens"
    unless tokens.empty?
      Rails.logger.info "Removing invalidated tokens from our DB"
      GT::ApplePushNotificationServicesManager.remove_device_tokens(tokens)
    else
      Rails.logger.info "Nothing to do"
    end
    Rails.logger.info "DONE"

  end

end