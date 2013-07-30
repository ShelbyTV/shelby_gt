# encoding: UTF-8
require 'api_clients/facebook_info_getter'

# Handles user's automated facebook interactions.
#
module GT
  class UserFacebookManager

    # Find all of the user's twitter friends and follow their shelby public rolls.
    # If they're a real Shelby user, they will get an email about the following.
    #
    def self.follow_all_friends_public_rolls(user)
      return unless user.has_provider? "facebook"
      self.friends_ids(user).each do |uid|
        friend = User.first( :conditions => { 'authentications.provider' => 'facebook', 'authentications.uid' => uid.to_s } )
        if friend and friend.public_roll and !user.unfollowed_roll?(friend.public_roll)
          friend.public_roll.add_follower(user)
          GT::Framer.backfill_dashboard_entries(user, friend.public_roll, 10)
        end
      end
    end

    def self.verify_auth(oauth_token)
      return false unless oauth_token

      begin
        graph = Koala::Facebook::API.new(oauth_token)
        graph.get_connections("me","permissions")
        return true
      rescue Koala::Facebook::APIError
        return false
      rescue => e
        StatsManager::StatsD.increment(Settings::StatsConstants.user['verify_service']['failure']['facebook'])
        return false
      end
    end

    private

      def self.friends_ids(user)
        APIClients::FacebookInfoGetter.new(user).get_friends_ids
      end

  end
end
