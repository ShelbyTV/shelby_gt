namespace :gt_migration do

  namespace :users do
    
    desc 'Make sure every user has a .public_roll and .watch_later_roll and that they follow them (idempotent)'
    task :ensure_special_rolls => :environment do
      require "user_manager"
      
      #can't pass :timeout => nil to find_each, so need to drop down to the driver...
      User.collection.find({}, {:timeout => false}) do |cursor| 
        cursor.each do |hsh| 
          u = User.load(hsh)
          if u.watch_later_roll_id == nil or u.public_roll_id == nil or u.upvoted_roll_id == nil or u.viewed_roll_id == nil
            print '*'
            GT::UserManager.ensure_users_special_rolls(u, true) 
          else
            print '.'
          end
        end
      end
      puts " done!"
    end
    
  end
  
end
