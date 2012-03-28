#
# Given a tweet, return a normalized Message
#
module GT
  class TumblrNormalizer
    
    # given a tweet hash, returns a new Message that can be added to a Conversation
    def self.normalize_post(post_hash)
      raise ArgumentError, "requires a hash representing the post" unless post_hash and post_hash.is_a?(Hash)

      return nil unless post_hash.size > 0
      
      if post_hash["blog_name"].include? "."
        user_image_url = "http://api.tumblr.com/v2/blog/"+ post_hash["blog_name"] + "/avatar/512"
      else 
        user_image_url = "http://api.tumblr.com/v2/blog/"+ post_hash["blog_name"] + ".tumblr.com/avatar/512"
      end
      
      
      m = GT::MessageManager.build_message( :origin_network => Message::ORIGIN_NETWORKS[:tumblr],
                                            :origin_id => post_hash['id'],
                                            # Tumblr uses your first blog's name as your user id
                                            :origin_user_id => post_hash["blog_name"],
                                            :public => true,
                                            :nickname => post_hash["blog_name"],
                                            :realname => post_hash["blog_name"],
                                            :user_image_url => user_image_url,
                                            :text => Sanitize.clean(post_hash["caption"]).strip )
      
      return m
    end
    
  end
end
