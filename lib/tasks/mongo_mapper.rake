# We need to override some of the stuff MongoMapper does by default.

namespace :db do
  
  namespace :test do
    
    # Since we don't use 1 DB with many collections (as MM default expects), go through all the DBs and all the test collections and drop them
    desc 'Iterate through all the DBs we use and drop all test collections'
    override_task :prepare => :environment do
      [DashboardEntry, Frame, Conversation, Roll, User, Video].each do |model|
        model.database.collections.select {|c| c.name !~ /system/ }.each(&:drop)
      end
    end
    
  end
  
  namespace :indexes do
    
    desc 'Ensure we have created the indexes we need'
    task :ensure => :environment do
      
      # Get the newest dashboard entries for a user
      DashboardEntry.ensure_index([[:user_id, 1], [:created_at, -1]], :background => false)
      
      # Get the highest scored frame for a given roll
      Frame.ensure_index([[:roll_id, 1], [:score, -1]], :background => true)
      
      #Get all the conversations related to a given video
      Conversation.ensure_index(:video_id, :background => true)
      
      # Get the rolls a given user has created
      Roll.ensure_index(:creator_id, :background => true)
          
      # Get a user by their nickname, ensure it's unique
      User.ensure_index(:nickname, :background => true, :unique => true)
      # Get a user given any casing of their nickname
      User.ensure_index(:downcase_nickname, :background => true)
      # Get a user by their primary email
      User.ensure_index(:primary_email, :background => true)
      # Compound index on authentications.provider and authentications.uid would create an innefficient BTree (could reverse order)
      # The following is good enuf, very little overlap between providers
      User.ensure_index('authentications.uid', :background => true)
      # Get user based on their nickname on a 3rd party network (facebook, twitter)
      User.ensure_index('authentications.nickname', :background => true)

      # Get a video from a provider (ie youtube video 123xyz), make sure they're unique
      Video.ensure_index([[:provider_name, 1], [:provider_id, 1]], :background => true, :unique => true)

    end
    
  end
  
end

# Before running tests, drop all the collections across the DBs and re-create the indexes
task 'spec' => ['db:test:prepare', 'db:indexes:ensure']