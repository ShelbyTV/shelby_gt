module MongoMapper
  class Helper
    
    def self.drop_all_dbs
      [DashboardEntry, DeeplinkCache, Frame, Conversation, Roll, User, Video, GtInterest].each do |model|
        model.database.collections.select {|c| c.name !~ /system/ }.each(&:drop)
      end
    end
    
    def self.ensure_all_indexes
      # Get all invites sent by a given user (a == sender_user_id)
      BetaInvite.ensure_index(:a, :background => true)
      # Get the invite through which a given user entered shelby (b == invitee_id)
      BetaInvite.ensure_index(:b, :background => true, :sparse => true)

      #Get all the conversations related to a given video (a == video_id)
      Conversation.ensure_index(:a, :background => true)
      #Get a conversation based on originating tweet/facebook update/tumblr/etc (don't need to add network to index, won't help much)
      Conversation.ensure_index('messages.b', :background => true, :unique => true, :sparse => true)
      
      # Get the newest dashboard entries for a user (a == user_id)
      DashboardEntry.ensure_index([[:a, 1], [:_id, -1]], :background => false)

      # Index over urls
      DeeplinkCache.ensure_index([[:a,1]], :background => true, :unique=>true)

      # Get the highest scored frame for a given roll (a == roll_id; e == score)
      Frame.ensure_index([[:a, 1], [:e, -1]], :background => true)
      
      # Get the rolls a given user has created (a == creator_id)
      Roll.ensure_index(:a, :background => true)
      # Get the rolls for a given subdomain (k == subdomain)
      Roll.ensure_index(:k, :background => true, :unique => true, :sparse => true)
          
      # Get a user by their nickname, ensure it's unique
      User.ensure_index(:nickname, :background => true, :unique => true)
      # Get a user given any casing of their nickname
      User.ensure_index(:downcase_nickname, :background => true, :unique => true)
      # Get a user by their primary email
      User.ensure_index(:primary_email, :background => true, :unique => true, :sparse => true)
      # Get a user by their authentication_token
      User.ensure_index(:ah, :background => true, :unique => true, :sparse => true)
      # the old index was on authentications.uid, now also have a unique index on uid and provider to make sure we don't overlap
      User.ensure_index('authentications.uid', :background => true)
      # sparse true allows documents to be missing these fields (otherwise, null is not unique from any other null)
      User.ensure_index([['authentications.uid', 1], ['authentications.provider', 1]], :background => true, :unique => true, :sparse => true)
      # Get user based on their nickname on a 3rd party network (facebook, twitter)
      User.ensure_index('authentications.nickname', :background => true)
      
      # Get UserAction by [user_id, type]
      UserAction.ensure_index([[:b, 1], [:a, 1]], :background => true)

      # Get a video from a provider (ie youtube video 123xyz), make sure they're unique (a == provider_name, b == provider_id)
      Video.ensure_index([[:a, 1], [:b, 1]], :background => true, :unique => true)
    end
    
  end
end
