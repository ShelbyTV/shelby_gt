require 'message_manager'

#
# Given a tweet, return a normalized Message
#
module GT
  class TwitterNormalizer
    
    # given a tweet hash, returns a new Message that can be added to a Conversation
    def self.normalize_tweet(tweet_hash)
      raise ArgumentError, "requires a hash representing the tweet" unless tweet_hash and tweet_hash.is_a?(Hash)

      return nil unless tweet_hash.size > 0 and !tweet_hash['user'].blank?
      user_hash = tweet_hash['user'] || {}
      
      m = GT::MessageManager.build_message( :origin_network => Message::ORIGIN_NETWORKS[:twitter],
                                            :origin_id => tweet_hash['id_str'].to_i,
                                            :origin_user_id => user_hash['id_str'].to_i,
                                            :public => true,
                                            :nickname => user_hash["screen_name"],
                                            :realname => user_hash["name"],
                                            :user_image_url => user_hash["profile_image_url"],
                                            :text => tweet_hash["text"] )
      
      
      return m
    end
    
  end
end