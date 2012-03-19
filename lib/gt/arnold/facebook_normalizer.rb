#
# Given a facebook post, return a normalized Message
#
module GT
  class FacebookNormalizer
    
    # given a post hash, returns a new Message that can be added to a Conversation
    def self.normalize_post(post_hash)
      raise ArgumentError, "requires a hash representing the facebook post" unless post_hash and post_hash.is_a?(Hash)

      return nil unless post_hash.size > 0 and !post_hash['from'].blank?
      user_hash = post_hash['from'] || {}
      
      m = Message.new
      m.origin_network = Message::ORIGIN_NETWORKS[:facebook]
      m.origin_id = post_hash["id"]
      m.origin_user_id = user_hash["id"]
      m.public = false
      
      m.nickname = user_hash["name"]
      m.realname = m.nickname
      m.user_image_url = "http://graph.facebook.com/" + user_hash["id"].to_s + "/picture"
      
      m.text = post_hash["message"] || post_hash["description"]
      
      return m
    end
    
  end
end