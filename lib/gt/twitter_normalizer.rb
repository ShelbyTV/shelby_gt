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
      
      m = Message.new
      m.origin_network = Message::ORIGIN_NETWORKS[:twitter]
      m.origin_id = tweet_hash['id']      
      m.origin_user_id = user_hash['id']
      m.public = true
      
      m.nickname = user_hash["screen_name"]
      m.realname = user_hash["name"]
      m.user_image_url = user_hash["profile_image_url"]
      
      m.text = tweet_hash["text"]
      
      return m
    end
    
  end
end