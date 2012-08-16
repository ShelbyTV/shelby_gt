module APIClients
  class FacebookInfoGetter
    
    def initialize(user)
      @user = user
      @fb_auth = user.authentications.select { |a| a.provider == 'facebook'  }.first
    end
    
    def get_following_ids
      friendsCollection = client.get_connections("me","friends")
      return all_pages_of_friends_ids(friendsCollection).uniq.compact
    end
    
    private
    
      def client
        unless @client
          @client = Koala::Facebook::API.new(fb_auth.oauth_token)
        end
        @client
      end
      
      def all_pages_of_friends_ids(friendsCollection)
        friends_ids = friendsCollection.map { |h| h["id"] }
        if friendsCollection.next_page.empty?
          return friends_ids
        else
          return freinds_ids + self.all_pages_of_friends_ids(friendsCollection.next_page)
        end
      end
    
  end  
end
