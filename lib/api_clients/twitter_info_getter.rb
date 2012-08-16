require "api_clients/twitter_client"

module APIClients

    class TwitterInfoGetter<TwitterClient

      def initialize(user)
        self.setup_for_user user
      end
      
      def get_following_ids
        # gets 5,000 ids at a time, we'll take a max of 5,000 for now
        twitter_client.friends.ids?.ids
      end

      def get_following_screen_names
        following_screen_names = []

        # two step process as required by twitter API:
        # 1) get user ids of who a user is following
        # 2) lookup user info for 100 user ids at a time - this info will contain the users' screen names
        friend_ids = get_following_ids
        # users can only be looked up 100 at a time to get their screen names
        friend_ids.each_slice(100) {|user_ids|
          user_info = twitter_client.users.lookup? :user_id => user_ids.join(",")
          following_screen_names.concat user_info.map{|user| user.screen_name}
        }

        return following_screen_names
      end

    end

end