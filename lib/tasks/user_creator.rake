namespace :wizard do

  desc 'Create a new User'
  task :create_new_user => :environment do
    require "user_creator_wizard"
    Dev::Wizard.create_user!
  end
end
