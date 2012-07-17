namespace :user_notifier do

  desc 'Send an email with all of todays new users w/basic info'
  task :todays_new_users => :environment do
    
    # create a bson id object that represents the beginning of the day
    start_at = Time.zone.now.beginning_of_day
    time_as_id = BSON::ObjectId.from_time(start_at)
    
    # find all new users as of today that are real users
    new_new_users = User.where('_id' => {'$gte' => time_as_id}, :faux => 0 ).all
    converted_new_users = User.where('_id' => {'$gte' => time_as_id}, :faux => 2 ).all
        
    # send email summary
    AdminMailer.new_user_summary(new_new_users, converted_new_users).deliver

  end
end


