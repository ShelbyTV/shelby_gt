namespace :gt_new_user_emails do
    
  desc 'Send Welcome Email to New Users'
  task :send_welcome_emails => :environment do
    require 'rhombus'
    require 'api_clients/sailthru_client'
    
    ###########
    # USING RHOMBUS to get all NEW NEW user and all NEW GT users
    #
    # Note: i think this is the only way of getting all new gt_enabled users, 
    #       hence using this method.
    rhombus_resp = JSON.parse(rhombus.get('/smembers', {:args => ['new_gt_enabled_users'], :limit=>24}))
    gt_enabled_ids = rhombus_resp["error"] ? [] : rhombus_resp["data"].values.flatten 
    new_gt_enabled_users = User.find(gt_enabled_ids)
    
    new_gt_enabled_users.each do |u|
      
      APIClients::SailthruClient.send_email(u, Settings::Sailthru.welcome_template)
      
    end
    
    #       #
    #  OR   #
    #       #
    
    ############
    # Using Time to get all users with ids since that time
    #  NOTE: this method does not get new gt_enabled users
    #
    
    # create a bson id object that represents 24 hrs ago
    #start_at = Time.zone.now - 1.day
    #time_as_id = BSON::ObjectId.from_time(start_at)
    
    # find all NEW users as of today that are gt_enabled users
    #User.where('id' => {'$gte' => time_as_id}, :gt_enabled => true ).all.each do |u|
    #  
    #  APIClients::SailthruClient.send_email(u, Settings::Sailthru.welcome_template)
    #  
    #end
    
    
  end

end