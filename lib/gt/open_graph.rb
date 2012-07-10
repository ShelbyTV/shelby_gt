module GT
  class OpenGraph
    
    def self.send_action(action, user, object, message=nil, expires_in=nil)
      raise ArgumentError, "must supply user" unless user.is_a?(User)
      raise ArgumentError, "must supply an action" unless action.is_a?(String)
      raise ArgumentError, "must supply a frame, roll, or conversation"  unless object.is_a?(Conversation) or object.is_a?(Frame) or object.is_a?(Roll)
      
      Rails.logger.info("[GT::OpenGraph] Would have sent OG action: #{action}") unless "production" == Rails.env
      
      # make sure the user wants us to send actions to facebook open graph
      return unless (["henry", "spinosa", "reece", "chris", "lauren"].include?(user.nickname)) and user.has_provider("facebook") and user.preferences.can_post_to_open_graph?
      
      og_object = {}
      
      case action
      when 'watch'
        og_action = "video.watches"
        og_object[:roll] = object.roll.permalink
        og_object[:video] = object.permalink
      when 'favorite'
        og_action = "shelbytv:favorite"
        og_object[:roll] = object.roll.permalink
        og_object[:other] = object.permalink
      when 'roll'
        og_action = "shelbytv:roll"
        og_object[:roll] = object.permalink
      when 'comment'
        conversation = object
        frame = conversation.frame
        og_action = "shelbytv:comment"
        og_object[:message] = message
        og_object[:roll] = frame.roll.permalink
        og_object[:other] = frame.permalink
      when 'share'
        og_action = "shelbytv:share"
        og_object[:message] = message
        if object.is_a?(Roll)
          og_object[:roll] = object.permalink
        elsif object.is_a?(Frame)
          og_object[:other] = object.permalink
        end
      end
      
      if og_action and post_to_og(user, og_action, og_object, expires_in) 
        Rails.logger.info("[OG POST] Posted: #{og_action}::  #{og_object}")
      end
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
          return false
        end
        
      end
          
  end
end