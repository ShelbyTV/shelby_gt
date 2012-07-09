module GT
  class OpenGraph
    
    def self.send_action(action, user, object, expires_in=nil)
      raise ArgumentError, "must supply user" unless user.is_a?(User)
      raise ArgumentError, "must supply an action" unless action.is_a?(String)
      raise ArgumentError, "must supply a frame or hash with conversation and message" unless object.is_a?(Frame) or (object.is_a?(Hash) and (object.has_key?(:message) and object.has_key?(:conversation)))
      
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
        conversation = object[:conversation]
        msg = object[:message]
        frame = conversation.frame
        og_action = "shelbytv:comment"
        og_object[:message] = msg.text
        og_object[:roll] = frame.roll.permalink
        og_object[:other] = frame.permalink
      when 'share'
        #TODO
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