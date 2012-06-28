module GT
  class OpenGraph
    
    def self.send_action(action, user, object, expires_in=nil)
      raise ArgumentError, "must supply user" unless user.is_a?(User)
      raise ArgumentError, "must supply an action" unless action.is_a?(String)
      raise ArgumentError, "must supply a frame or roll" unless object.is_a?(Frame) or object.is_a?(Roll) or object.is_a?(Hash)
      
      Rails.logger.info("[GT::OpenGraph] Would have sent OG action: #{action}") unless "production" == Rails.env
      
      # make sure the user wants us to send actions to facebook open graph
      return unless user.has_provider("facebook") and user.preferences.can_post_to_open_graph?
      
      og_url = "http://gt.shelby.tv/roll/#{object.roll.id.to_s}/frame/#{object.id.to_s}"
      og_object = {:video => og_url}
      
      case action
      when 'watch'
        og_action = "video.watches"
      when 'favorite'
        og_action = "shelbytv:favorite"
      when 'roll'
        og_action = "shelbytv:roll"
      when 'comment'
        conversation = object[:conversation]
        msg = object[:message]
        og_url = "http://gt.shelby.tv/roll/#{conversation.frame.roll.id.to_s}/frame/#{conversation.frame.id.to_s}"
        og_object[:video] = og_url
        og_action = "shelbytv:comment"
      end
      
      post_to_og(user, og_action, og_object, expires_in)
    end
    
    private
      
      def self.post_to_og(user, action, object, expires_in=nil)
        
        # get the users fb oauth token
        user.authentications.each { |a| @fb_token = a.oauth_token if a.provider == "facebook"}
        
        # post action/object connection to fb
        begin
          graph = Koala::Facebook::GraphAPI.new(@fb_token)
          
          object[:expires_in] = expires_in if expires_in
          graph.put_connections("me", action, object)
          
          return true
        rescue => e
          Rails.logger.error("[FB OG: ERROR] #{e}")
          return nil
        end
        
      end
          
  end
end