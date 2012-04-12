module GT
  class NotificationManager
    
    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?
      
      # don't email the creator if they are the upvoting user!
      return if user.id == frame.creator_id
      
      NotificationMailer.upvote_notification(user, frame.creator, frame).deliver
    end
    
    def self.check_and_send_comment_notification(user, conversation)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid conversation" unless conversation.is_a?(Conversation) and !conversation.blank?
      
      # cant email anyone if the conversation initiator is not a shelby user :)
      return if conversation.messages.first.user.faux == User::FAUX_STATUS[:true]
      
      NotificationMailer.comment_notification(user, frame.creator, conversation).deliver
    end
    
  end
end