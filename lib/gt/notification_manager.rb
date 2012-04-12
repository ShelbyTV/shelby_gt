module GT
  class NotificationManager
    
    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?
      
      # don't email the creator if they are the upvoting user!
      return unless (user.id != frame.creator_id) and user.primary_email
      
      NotificationMailer.upvote_notification(user, frame.creator, frame).deliver
    end
    
    def self.check_and_send_comment_notification(user, conversation)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid conversation" unless conversation.is_a?(Conversation) and !conversation.blank?
      
      first_message = conversation.messages.first
      
      # cant email anyone if we dont have their email address :)
      return unless first_message and first_message.user and first_message.user.primary_email
      
      NotificationMailer.comment_notification(user, first_message.user, conversation).deliver
    end
    
  end
end