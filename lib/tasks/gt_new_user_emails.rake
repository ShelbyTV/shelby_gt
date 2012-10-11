namespace :gt_new_user_emails do
    
  desc 'Send Welcome Email to New Users'
  task :send_welcome_emails => :environment do
    require 'api_clients/sailthru_client'
    
    # create a bson id object that represents 24 hrs ago
    start_at = Time.zone.now - 1.day
    time_as_id = BSON::ObjectId.from_time(start_at)
    
    # find all new users as of today that are gt_enabled users
    User.where('id' => {'$gte' => time_as_id}, :gt_enabled => true ).all.each do |u|
      
      APIClients::SailthruClient.send_email(u, Settings::Sailthru.welcome_template)
      
    end
    
  end

end