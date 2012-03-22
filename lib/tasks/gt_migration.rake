namespace :gt_migration do

  namespace :users do
    
    desc 'Make sure every user has a .public_roll and .watch_later_roll and that they follow them (idempotent)'
    task :ensure_special_rolls => :environment do
      require "user_manager"
      User.find_each do |u| 
        print '.'
        GT::UserManager.ensure_users_special_rolls(u)
      end
      puts " done!"
    end
    
  end
  
end
