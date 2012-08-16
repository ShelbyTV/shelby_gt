# encoding: UTF-8
require 'api_clients/twitter_client'
require 'api_clients/twitter_info_getter'


# Handles user's automated Twitter interactions.
#
module GT
  class UserTwitterManager
    
    # Find all of the user's twitter friends and follow their shelby public rolls.
    # If they're a real Shelby user, they will get an email about the following.
    # 
    def self.follow_all_friends_public_rolls(user)
      self.friends_ids(user).each do |uid|
        friend = User.first( :conditions => { 'authentications.provider' => 'twitter', 'authentications.uid' => uid.to_s } )
        friend.public_roll.add_follower(user) if friend and friend.public_roll and !user.unfollowed_roll?(friend.public_roll)
      end
    end
    
    def self.verify_auth(oauth_token, oauth_secret)
      return false unless oauth_token and oauth_secret
      
      begin
        c = APIClients::TwitterClient.build_for_token_and_secret(oauth_token, oauth_secret)
        #this will throw if user isn't auth'd
        c.statuses.home_timeline? :count => 1
        return true
      rescue Grackle::TwitterError
        return false
      rescue => e
        StatsManager::StatsD.increment(Settings::StatsConstants.user['verify_service']['failure']['twitter'])
        return false
      end
    end
    
    private
    
      def self.friends_ids(user)
        APIClients::TwitterInfoGetter.new(user).get_following_ids
      end
    
  end
end
