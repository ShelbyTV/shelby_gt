#
# Given a tweet, return a normalized Message
#
module GT
  class TumblrNormalizer
    
    # given a tweet hash, returns a new Message that can be added to a Conversation
    def self.normalize_post(post_hash)
      raise ArgumentError, "requires a hash representing the post" unless post_hash and post_hash.is_a?(Hash)

      return nil unless post_hash.size > 0
      
      m = Message.new
      m.origin_network = Message::ORIGIN_NETWORKS[:tumblr]
      m.origin_id = post_hash['id']
      # Tumblr uses your first blog's name as your user id
      m.origin_user_id = post_hash["blog_name"]
      m.public = true
      
      m.nickname = post_hash["blog_name"]
      m.realname = m.nickname
      
      if post_hash["blog_name"].include? "."
        m.user_image_url = "http://api.tumblr.com/v2/blog/"+ post_hash["blog_name"] + "/avatar/512"
      else 
        m.user_image_url = "http://api.tumblr.com/v2/blog/"+ post_hash["blog_name"] + ".tumblr.com/avatar/512"
      end
      
      m.text = Sanitize.clean(post_hash["caption"]).strip
      
      return m
    end
    
  end
end
