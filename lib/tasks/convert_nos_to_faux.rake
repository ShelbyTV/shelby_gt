namespace :users do

    desc 'Convert all NOS users to faux users'
    task :convert_nos_to_faux => :environment do
      require "user_manager"

      puts "Processing users"

      #can't pass :timeout => nil to find_each, so need to drop down to the driver...
      User.collection.find({}, {:timeout => false}) do |cursor|
        cursor.each do |hsh|
          begin
            u = User.load(hsh)
            if u.user_type == User::USER_TYPE[:real] && !u.gt_enabled
              #if it's a NOS user, convert to faux
              GT::UserManager.convert_real_user_to_faux(u)
              print '.'
            else
              #while we're at it, if they're not a NOS user, correct their app progress to the current format
              GT::UserManager.update_app_progress_onboarding(u)
              print '*'
            end
          rescue Exception => e
            puts ""
            puts "[convert_nos_to_faux] EXCEPTION PROCESSING USER #{u.id.to_s}: #{e}"
          end
        end
      end
      puts " done!"
    end

end
