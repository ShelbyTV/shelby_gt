module APIClients

  # NB: Clients of this module are expected to handle all Grackle::TwitterError errors themselves
  # The module does not do so because it cannot know if a twitter error constitutes an actual
  # exception for the particular client situation

  # Two usage patterns:

  # 1) Create a Grackle twitter client for one time use:

  #   c = APIClients::TwitterClient.build_for_token_and_secret(oauth_token, oauth_secret)
  #   begin
  #     -- perform some twitter operations such as --
  #     friend_ids = c.friends.ids?
  #   rescue Grackle::TwitterError
  #     -- handle any twitter errors
  #   end

  # 2) Mixin to a class that will be used for (possibly multiple) twitter queries for a user or user(s)

  #   class TwitterQueryingClass<TwitterClient

  #     -- can call the private methods setup_for_user or setup_for_token_and_secret any time
  #     -- to configure twitter client with an authed user

  #     def setup_my_twitter_info
  #       setup_for_user(user_object)

  #       -- OR --

  #       setup_for_token_and_secret(token, secret)

  #     end

  #     ...

  #     -- private method twitter_client will return a Grackle twitter client ready to go
  #     -- configured as specified in the setup* methods

  #     def do_some_twitter_query
  #       begin
  #         -- perform some twitter operations such as --
  #         friend_ids = twitter_client.friends.ids?
  #       rescue Grackle::TwitterError
  #         -- handle any twitter errors
  #       end

  #       return friend_ids
  #     end

  #   --then a client of the class can call repeatedly, for example
  #     q = TwitterQueryingClass.new
  #       q.setup_for_user(u1)
  #       info_for_u1 = q.do_some_twitter_query
  #       --do something with info_for_u1--
  #       ...
  #       q.setup_for_user(u2)
  #       info_for_u2 = q.do_some_twitter_query
  #       --do something with info_for_u2--
  #       ...
  #       --and so on

  #   end

  class TwitterClient

    # build a client on behalf of a user who has granted us access
    def self.build_for_token_and_secret(oauth_token, oauth_secret)
      ensure_token_and_secret(oauth_token, oauth_secret)
      build_client(oauth_token, oauth_secret)
    end

    # build a client on behalf our app, NB: different rate limits
    def self.build_for_app
      build_client
    end

    def setup_for_user(user)
      raise ArgumentError, 'Must provide User' unless @user = user
      twitter_auth = @user.authentications.select { |a| a.provider == 'twitter'  }.first
      raise ArgumentError, 'User must have twitter authentication' unless twitter_auth
      @oauth_token = twitter_auth.oauth_token
      @oauth_secret = twitter_auth.oauth_secret
      @user_id = twitter_auth.uid
      # if setup succeeds, get rid of any previous client so it will be recreated for the new user
      @client = nil
    end

    def setup_for_token_and_secret(oauth_token, oauth_secret)
      self.class.ensure_token_and_secret(oauth_token, oauth_secret)
      @oauth_token = oauth_token
      @oauth_secret = oauth_secret
      # if setup succeeds, get rid of any previous client so it will be recreated for the new auth info
      @client = nil
    end

    def twitter_client
      @client ||= self.class.build_client(@oauth_token, @oauth_secret)
    end

    private

      def self.ensure_token_and_secret(oauth_token, oauth_secret)
        raise ArgumentError, 'Must provide oauth token' unless oauth_token
        raise ArgumentError, 'Must provide oauth secret' unless oauth_secret
      end

      def self.build_client(oauth_token=nil, oauth_secret=nil)
        auth = {
          :type => :oauth,
          :consumer_key => Settings::Twitter.consumer_key,
          :consumer_secret => Settings::Twitter.consumer_secret
        }
        auth[:token] = oauth_token if oauth_token
        auth[:token_secret] = oauth_secret if oauth_secret
        Grackle::Client.new(:ssl => true, :auth => auth)
      end

  end

end
