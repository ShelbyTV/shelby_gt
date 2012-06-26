require 'message_manager'

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
      
      user_image_url = "http://graph.facebook.com/" + user_hash["id"].to_s + "/picture"
      
      m = GT::MessageManager.build_message( :origin_network => Message::ORIGIN_NETWORKS[:facebook],
                                            :origin_id => post_hash["id"],
                                            :origin_user_id => user_hash["id"],
                                            :public => true,
                                            :nickname => user_hash["name"],
                                            :realname => user_hash["name"],
                                            :user_image_url => user_image_url,
                                            :text => post_hash["message"] || post_hash["description"] )

      return m
    end
    
  end
end