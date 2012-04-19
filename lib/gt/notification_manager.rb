module GT
  class NotificationManager
    
    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?
      
      # don't email the creator if they are the upvoting user!
      return unless (user.id != frame.creator_id) and user.primary_email
      
      if Rails.env == "production"
        # only sending notifications for a select few for now
        return unless ["henry", "reece", "onshelby"].include?(frame.creator.nickname)
      end
      
      
      NotificationMailer.upvote_notification(frame.creator, user, frame).deliver
    end
    
    def self.check_and_send_comment_notification(user, c, message)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid conversation" unless c.is_a?(Conversation) and !c.blank?
      raise ArgumentError, "must supply valid message" unless message.is_a?(Message) and !message.blank?
      
      first_message = c.messages.first
      
      c.messages.each do |m|
        # stop if the message user is the current user
        break if m.user == user
        
        # cant email anyone if we dont have their email address :)
        break unless m and m.user and m.user.primary_email
        
        if Rails.env == "production"
          # only sending notifications for a select few for now
          break unless ["henrysztul", "reece", "spinosa", "onshelby"].include?(m.user.nickname)
        end
        
        NotificationMailer.comment_notification(first_message.user, m.user, c, m).deliver
      end
    end
  end
end