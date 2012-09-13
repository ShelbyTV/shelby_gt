module APIClients
  class FacebookInfoGetter
    
    def initialize(user)
      @user = user
      @fb_auth = user.authentications.select { |a| a.provider == 'facebook'  }.first
      raise ArgumentError, "User must have a Facebook authentication" unless @fb_auth
    end
    
    # A hash where the keys are FB user names and values are FB user ids
    def get_friends_names_ids_dictionary
      friends_collection = client.get_connections("me","friends")
      return all_pages_of_friends_name_id_dictionary(friends_collection)
    end
    
    def get_friends_ids
      get_friends_names_ids_dictionary.values
    end
    
    def get_friends_names
      get_friends_names_ids_dictionary.keys
    end
    
    private
    
      def client
        unless @client
          @client = Koala::Facebook::API.new(@fb_auth.oauth_token)
        end
        @client
      end
      
      def all_pages_of_friends_name_id_dictionary(friends_collection)
        friends_name_id_dict = {}
        friends_collection.each { |h| friends_name_id_dict[h["name"]] = h["id"] if h["name"] and h["id"] }
        
        if !friends_collection.next_page or friends_collection.next_page.empty?
          return friends_name_id_dict
        else
          return friends_name_id_dict.merge( self.all_pages_of_friends_name_id_dictionary(friends_collection.next_page) )
        end
      end
    
  end  
end
